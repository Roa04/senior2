import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config.dart';
import '../models/models.dart';
import 'cloud_api.dart';
import 'reading_source.dart';

enum BleStatus { bluetoothOff, scanning, connecting, connected, disconnected }

/// Real data source: connects to the ESP32 wristband over BLE, buffers the
/// ECG, sends it to the cloud AI every [kAnalyzeEverySeconds] and emits a
/// VitalReading. Reconnects automatically (FR-02 / NFR-02).
///
/// BLE format (see BLE_CONTRACT.md):
///  - Vitals notify: 4 bytes  [hr uint16 LE][spo2 uint8][flags uint8]
///        flags bit0 = fall detected, bit1 = finger not on sensor
///  - ECG notify: int16 LE samples (up to 10 per packet) at 250 Hz
class BleReadingSource implements ReadingSource {
  final PatientProfile Function() profile;
  BleReadingSource({required this.profile});

  final _controller = StreamController<VitalReading>.broadcast();
  final ValueNotifier<BleStatus> status = ValueNotifier(BleStatus.disconnected);
  final ValueNotifier<String?> cloudError = ValueNotifier(null);

  bool _running = false;
  BluetoothDevice? _device;
  StreamSubscription? _vitalsSub, _ecgSub, _connSub;
  Timer? _timer;
  bool _analyzing = false;
  int _counter = 0;

  final List<double> _ecg = [];
  int _hr = 0, _spo2 = 0;
  bool _fall = false, _fingerOff = false;

  @override
  Stream<VitalReading> get readings => _controller.stream;

  @override
  void start() {
    _running = true;
    _connectLoop();
    _timer = Timer.periodic(const Duration(seconds: kAnalyzeEverySeconds), (_) => _analyze());
  }

  @override
  void dispose() {
    _running = false;
    _timer?.cancel();
    _vitalsSub?.cancel();
    _ecgSub?.cancel();
    _connSub?.cancel();
    try {
      _device?.disconnect();
    } catch (_) {}
    _controller.close();
    status.dispose();
    cloudError.dispose();
  }

  // ---------------- connection ----------------

  Future<void> _connectLoop() async {
    while (_running) {
      try {
        final adapter = await FlutterBluePlus.adapterState.first;
        if (adapter != BluetoothAdapterState.on) {
          _setStatus(BleStatus.bluetoothOff);
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        _setStatus(BleStatus.scanning);
        final found = Completer<BluetoothDevice?>();
        final scanSub = FlutterBluePlus.scanResults.listen((results) {
          if (results.isNotEmpty && !found.isCompleted) found.complete(results.first.device);
        });
        await FlutterBluePlus.startScan(
            withNames: [kBleDeviceName], timeout: const Duration(seconds: 8));
        final dev = await found.future
            .timeout(const Duration(seconds: 9), onTimeout: () => null);
        await scanSub.cancel();
        await FlutterBluePlus.stopScan();
        if (dev == null) {
          _setStatus(BleStatus.disconnected);
          continue; // scan again
        }

        _setStatus(BleStatus.connecting);
        _device = dev;
        await dev.connect(timeout: const Duration(seconds: 12));

        final services = await dev.discoverServices();
        final svc = services.firstWhere((s) => s.uuid == Guid(kBleServiceUuid));
        final vitals = svc.characteristics.firstWhere((c) => c.uuid == Guid(kBleVitalsUuid));
        final ecg = svc.characteristics.firstWhere((c) => c.uuid == Guid(kBleEcgUuid));

        _vitalsSub = vitals.onValueReceived.listen(_onVitals);
        _ecgSub = ecg.onValueReceived.listen(_onEcg);
        await vitals.setNotifyValue(true);
        await ecg.setNotifyValue(true);

        final lost = Completer<void>();
        _connSub = dev.connectionState.listen((s) {
          if (s == BluetoothConnectionState.disconnected && !lost.isCompleted) lost.complete();
        });
        _setStatus(BleStatus.connected);
        await lost.future; // stays here until the wristband disconnects
      } catch (e) {
        debugPrint('BLE error: $e');
      }
      await _vitalsSub?.cancel();
      await _ecgSub?.cancel();
      await _connSub?.cancel();
      _setStatus(BleStatus.disconnected);
      if (_running) await Future.delayed(const Duration(seconds: 3));
    }
  }

  void _setStatus(BleStatus s) {
    if (_running) status.value = s;
  }

  // ---------------- incoming data ----------------

  void _onVitals(List<int> v) {
    if (v.length < 4) return;
    _hr = v[0] | (v[1] << 8);
    _spo2 = v[2];
    _fall = (v[3] & 0x01) != 0;
    _fingerOff = (v[3] & 0x02) != 0;
  }

  void _onEcg(List<int> v) {
    final bd = ByteData.sublistView(Uint8List.fromList(v));
    for (var i = 0; i + 1 < v.length; i += 2) {
      _ecg.add(bd.getInt16(i, Endian.little).toDouble());
    }
    const maxLen = kEcgSampleRate * kEcgWindowSeconds;
    if (_ecg.length > maxLen) _ecg.removeRange(0, _ecg.length - maxLen);
  }

  // ---------------- AI ----------------

  Future<void> _analyze() async {
    if (_analyzing || !_running) return;
    if (status.value != BleStatus.connected) return;
    if (_hr <= 0 || _fingerOff) return; // no valid measurement yet
    if (_ecg.length < kEcgSampleRate * 5) return; // need >= 5 s
    _analyzing = true;
    try {
      final window = List<double>.from(_ecg);
      final res = await CloudApi.analyze(
        ecg: window,
        heartRate: _hr,
        fallDetected: _fall,
        profile: profile(),
      );
      cloudError.value = null;
      if (_controller.isClosed) return;
      _controller.add(_toReading(res, window));
    } catch (e) {
      cloudError.value = 'AI server unreachable. Check Wi-Fi and server.';
      debugPrint('Cloud error: $e');
    } finally {
      _analyzing = false;
    }
  }

  VitalReading _toReading(CloudResult res, List<double> window) {
    // Waveform preview: last 2 s, scaled to [-1, 1], ~50 points.
    final tail = window.length > 500 ? window.sublist(window.length - 500) : window;
    final peak = tail.fold<double>(1, (m, x) => x.abs() > m ? x.abs() : m);
    final step = (tail.length / 50).ceil().clamp(1, 1000);
    final preview = [for (var i = 0; i < tail.length; i += step) tail[i] / peak];

    // The UI shows a diagnostic code; map the 3 AI classes to codes.
    final code = {
      RiskLevel.normal: 'NORM',
      RiskLevel.abnormal: 'ABN',
      RiskLevel.critical: 'MI',
    }[res.risk]!;
    final conf = (res.ecgProbabilities.values.fold<double>(0, (m, x) => x > m ? x : m)) * 100;

    _counter++;
    return VitalReading(
      timestamp: DateTime.now(),
      heartRate: _hr,
      spo2: _spo2,
      ppgStatus: _fingerOff ? 'No finger' : 'Stable',
      ecg: EcgRecord(
        ecgId: 'ble-${_counter.toString().padLeft(5, '0')}',
        patientId: 0,
        samplingRateHz: kEcgSampleRate,
        leadII: preview,
        scpCodes: {code: conf},
        risk: res.risk,
      ),
    );
  }
}

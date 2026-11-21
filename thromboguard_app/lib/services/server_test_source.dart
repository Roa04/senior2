import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/models.dart';
import 'cloud_api.dart';
import 'reading_source.dart';

/// TEST SOURCE (no device needed): builds a synthetic 10 s ECG (250 Hz) and
/// sends it to the real server (POST /analyze). Use it to check that
/// app -> server works. The signal is synthetic, so the ECG result is NOT
/// medically meaningful; only the connection and the vitals logic are tested.
/// Every 3rd request sends a low SpO2 (85) to test the vitals rule.
class ServerTestSource implements ReadingSource {
  final PatientProfile Function() profile;
  ServerTestSource({required this.profile});

  final _controller = StreamController<VitalReading>.broadcast();
  final Random _rng = Random();
  Timer? _timer;
  int _n = 0;
  bool _busy = false;

  /// Last server error (shown in the debug console).
  final ValueNotifier<String?> cloudError = ValueNotifier(null);

  @override
  Stream<VitalReading> get readings => _controller.stream;

  @override
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
    _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  List<double> _syntheticEcg() {
    final fs = kEcgSampleRate;
    final total = fs * kEcgWindowSeconds;
    final beat = (fs * 0.83).round(); // ~72 bpm
    final out = List<double>.filled(total, 0);
    for (var i = 0; i < total; i++) {
      final k = i % beat;
      final r = 800 * exp(-pow((k - 20) / 3.0, 2)); // R spike
      final t = 150 * exp(-pow((k - 70) / 14.0, 2)); // T wave
      out[i] = r + t + (_rng.nextDouble() - 0.5) * 20;
    }
    return out;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    _n++;
    final lowSpo2 = _n % 3 == 0;
    final hr = 72;
    final spo2 = lowSpo2 ? 85 : 97;
    try {
      final res = await CloudApi.analyze(
        ecg: _syntheticEcg(),
        heartRate: hr,
        spo2: spo2,
        fallDetected: false,
        profile: profile(),
      );
      cloudError.value = null;
      debugPrint('SERVER OK: ${res.risk} ${res.reasons} ${res.message}');
      if (_controller.isClosed) return;
      final code = {
        RiskLevel.normal: 'NORM',
        RiskLevel.abnormal: 'ABN',
        RiskLevel.critical: 'MI',
      }[res.risk]!;
      final conf = res.ecgProbabilities.values.fold<double>(0, (m, x) => x > m ? x : m) * 100;
      _controller.add(VitalReading(
        timestamp: DateTime.now(),
        heartRate: hr,
        spo2: spo2,
        ppgStatus: 'Stable',
        ecg: EcgRecord(
          ecgId: 'srvtest-${_n.toString().padLeft(5, '0')}',
          patientId: 0,
          samplingRateHz: kEcgSampleRate,
          leadII: List.generate(50, (i) => sin(i / 3)),
          scpCodes: {code: conf},
          risk: res.risk,
        ),
      ));
    } on CloudSignalException catch (e) {
      cloudError.value = 'Signal problem: ${e.message}';
      debugPrint('SERVER signal problem: $e');
    } catch (e) {
      cloudError.value = 'AI server unreachable. Check Wi-Fi and server.';
      debugPrint('SERVER unreachable: $e');
    } finally {
      _busy = false;
    }
  }
}

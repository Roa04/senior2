import 'dart:async';
import 'dart:math';
import '../models/models.dart';
import 'reading_source.dart';

/// ---------------------------------------------------------------------
/// This service is shaped around the PTB-XL dataset
/// (https://physionet.org/content/ptb-xl/1.0.3/) so that swapping the
/// simulated data source for the real one later is mostly a matter of
/// replacing `_fetchNextRecord()`.
///
/// PTB-XL background (for the real integration step):
/// - 21,799 clinical 12-lead ECG records from 18,869 patients, 10s each,
///   provided at 100Hz and 500Hz sampling rates as WFDB (.dat/.hea) files.
/// - Each record has one or more `scp_codes`: standardized SCP-ECG
///   diagnostic statements with a likelihood (0-100), e.g.
///   {"NORM": 100.0} or {"IMI": 80.0, "ASMI": 50.0}.
/// - PTB-XL groups those statements into 5 diagnostic superclasses:
///   NORM, MI, STTC, CD, HYP. This app maps them to the 3-level risk
///   scheme used in the wristband report:
///     NORM                -> normal   (Green)
///     STTC / CD / HYP     -> abnormal (Yellow)
///     MI                  -> critical (Red)
///
/// REAL INTEGRATION PATH (Senior Project II):
/// 1. Ship a trained classifier (e.g. a CNN over the 12-lead signal,
///    trained on PTB-XL's `scp_codes` labels) on your cloud backend.
/// 2. The ESP32/AD8232 wristband streams a single-lead ECG waveform over
///    BLE to this app; the app forwards it (or the MAX30102/MPU6050
///    fused features) to that backend over HTTPS.
/// 3. The backend returns a JSON payload shaped like `scp_codes` above;
///    replace `_classifyScpCodes()` below with that response and this
///    whole app keeps working unchanged, since the UI only depends on
///    the `RiskLevel` derived from those codes.
/// 4. For local dataset exploration/training, PTB-XL ships
///    `ptbxl_database.csv` (metadata + scp_codes per ecg_id) and the
///    waveform files read via the `wfdb` Python package — that part
///    happens offline/on the training machine, not inside this app.
/// ---------------------------------------------------------------------
class PtbxlService implements ReadingSource {
  final _controller = StreamController<VitalReading>.broadcast();
  final Random _rng = Random();
  Timer? _timer;
  int _counter = 0;

  @override
  Stream<VitalReading> get readings => _controller.stream;

  @override
  void start({Duration interval = const Duration(seconds: 4)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _controller.add(_fetchNextRecord()));
    _controller.add(_fetchNextRecord());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  /// Simulated fetch of one classified ECG record. In production this
  /// calls your cloud inference endpoint with the live waveform and
  /// parses back a `scp_codes`-shaped response.
  VitalReading _fetchNextRecord() {
    _counter++;
    final roll = _rng.nextDouble();

    Map<String, double> scpCodes;
    int hr;
    int spo2;
    String ppg;

    if (roll < 0.7) {
      scpCodes = {'NORM': 100.0};
      hr = 60 + _rng.nextInt(21);
      spo2 = 96 + _rng.nextInt(4);
      ppg = 'Stable';
    } else if (roll < 0.92) {
      // STTC/CD/HYP-style non-lethal abnormality
      final codes = ['STTC', 'CD', 'HYP'];
      scpCodes = {codes[_rng.nextInt(codes.length)]: 60.0 + _rng.nextInt(30)};
      hr = 82 + _rng.nextInt(20);
      spo2 = 93 + _rng.nextInt(5);
      ppg = 'Stable';
    } else {
      // MI-style critical finding (as PTB-XL's "MI" superclass)
      final miCodes = ['IMI', 'ASMI', 'ILMI'];
      scpCodes = {miCodes[_rng.nextInt(miCodes.length)]: 70.0 + _rng.nextInt(30)};
      hr = 105 + _rng.nextInt(30);
      spo2 = 88 + _rng.nextInt(7);
      ppg = 'Irregular';
    }

    final record = EcgRecord(
      ecgId: 'sim-${_counter.toString().padLeft(5, '0')}',
      patientId: 1001,
      samplingRateHz: 100,
      leadII: List.generate(50, (i) => sin(i / 3) + (_rng.nextDouble() - 0.5) * 0.2),
      scpCodes: scpCodes,
      risk: classifyFromScpCodes(scpCodes),
    );

    return VitalReading(
      timestamp: DateTime.now(),
      heartRate: hr,
      spo2: spo2,
      ppgStatus: ppg,
      ecg: record,
    );
  }

  /// Maps a PTB-XL-style `scp_codes` map to the 3-level risk scheme.
  static RiskLevel classifyFromScpCodes(Map<String, double> scpCodes) {
    const miCodes = {
      'IMI', 'ASMI', 'ILMI', 'AMI', 'ALMI', 'INJAS', 'INJAL', 'INJIN',
      'INJLA', 'PMI', 'IPLMI', 'IPMI',
    };
    const abnormalSuperclassCodes = {
      // STTC
      'NDT', 'NST_', 'DIG', 'LNGQT', 'ISC_', 'ISCAL', 'ISCIN', 'ISCIL',
      'ISCAS', 'ISCALS', 'ISCLA', 'ANEUR', 'EL', 'STD_', 'STE_',
      // CD
      'LAFB', 'IRBBB', 'CLBBB', 'CRBBB', 'IVCD', 'ILBBB', '1AVB', '2AVB',
      '3AVB', 'WPW',
      // HYP
      'LVH', 'RVH', 'LAO/LAE', 'RAO/RAE', 'SEHYP',
    };

    if (scpCodes.keys.any((k) => miCodes.contains(k))) return RiskLevel.critical;
    if (scpCodes.keys.any((k) => abnormalSuperclassCodes.contains(k))) {
      return RiskLevel.abnormal;
    }
    return RiskLevel.normal;
  }

  static String generateHealthTip(VitalReading r) {
    switch (r.risk) {
      case RiskLevel.normal:
        return 'Your blood oxygen levels and resting heart rate are perfect right now. Keep up your current daily hydration targets.';
      case RiskLevel.abnormal:
        final code = r.ecg.scpCodes.keys.first;
        return 'ECG finding "$code" detected alongside a heart rate of ${r.heartRate} bpm. Rest for a few minutes and re-check; contact your doctor if it persists.';
      case RiskLevel.critical:
        final code = r.ecg.scpCodes.keys.first;
        return 'Finding "$code" is consistent with a possible Myocardial Infarction. Heart rate ${r.heartRate} bpm, SpO2 ${r.spo2}%. Emergency contacts and services are being notified automatically.';
    }
  }
}

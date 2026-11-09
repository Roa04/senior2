/// ---------------------------------------------------------------------
/// Risk levels shown in the UI (Green / Yellow / Red in the mockups).
/// These map from the SCP-ECG diagnostic superclasses used by PTB-XL:
///   NORM                       -> normal
///   STTC, CD, HYP (non-lethal) -> abnormal
///   MI (Myocardial Infarction) -> critical
/// ---------------------------------------------------------------------
enum RiskLevel { normal, abnormal, critical }

extension RiskLevelX on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.normal:
        return 'Normal';
      case RiskLevel.abnormal:
        return 'Abnormal';
      case RiskLevel.critical:
        return 'Critical';
    }
  }
}

/// A single ECG record shaped like a row of PTB-XL's `ptbxl_database.csv`
/// joined with its waveform samples, trimmed to the fields this app needs.
///
/// PTB-XL specifics this mirrors:
/// - `ecg_id`, `patient_id`               -> record identifiers
/// - 12-lead signal, sampled at 100 Hz or 500 Hz, 10 seconds long
///   (i.e. 1000 or 5000 samples per lead) -> `leadII` here (single-lead
///   preview, since the wristband's AD8232 is single-lead)
/// - `scp_codes`                          -> `scpCodes` (diagnostic
///   statement -> likelihood, exactly as stored in PTB-XL, e.g.
///   {"NORM": 100.0} or {"IMI": 80.0, "NORM": 0.0})
/// - `heart_axis`, `report`               -> optional metadata
class EcgRecord {
  final String ecgId;
  final int patientId;
  final int samplingRateHz; // PTB-XL provides 100 Hz and 500 Hz versions
  final List<double> leadII; // simplified single-lead waveform preview
  final Map<String, double> scpCodes; // PTB-XL diagnostic statement codes
  final RiskLevel risk; // derived from scpCodes by classifyFromScpCodes()

  EcgRecord({
    required this.ecgId,
    required this.patientId,
    required this.samplingRateHz,
    required this.leadII,
    required this.scpCodes,
    required this.risk,
  });
}

/// One "live" vitals snapshot combining the ECG record classification
/// with the wristband's other sensors (MAX30102 HR/SpO2), for the
/// dashboard cards.
class VitalReading {
  final DateTime timestamp;
  final int heartRate; // bpm, from MAX30102
  final int spo2; // %, from MAX30102
  final String ppgStatus; // "Stable" / "Irregular"
  final EcgRecord ecg; // PTB-XL-shaped ECG classification result

  VitalReading({
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.ppgStatus,
    required this.ecg,
  });

  RiskLevel get risk => ecg.risk;

  /// Stored in Firestore WITHOUT the raw waveform (keeps documents small).
  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.millisecondsSinceEpoch,
        'heartRate': heartRate,
        'spo2': spo2,
        'ppgStatus': ppgStatus,
        'ecgId': ecg.ecgId,
        'samplingRateHz': ecg.samplingRateHz,
        'scpCodes': ecg.scpCodes,
        'risk': risk.name,
      };

  factory VitalReading.fromMap(Map<String, dynamic> m) {
    final codes = Map<String, double>.from(
        (m['scpCodes'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    return VitalReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
      heartRate: m['heartRate'] as int,
      spo2: m['spo2'] as int,
      ppgStatus: (m['ppgStatus'] ?? 'Stable') as String,
      ecg: EcgRecord(
        ecgId: (m['ecgId'] ?? '') as String,
        patientId: 0,
        samplingRateHz: (m['samplingRateHz'] ?? 100) as int,
        leadII: const [],
        scpCodes: codes,
        risk: RiskLevel.values.firstWhere((r) => r.name == m['risk'], orElse: () => RiskLevel.normal),
      ),
    );
  }
}

class EmergencyContact {
  String name;
  String phone;

  EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromMap(Map<String, dynamic> m) =>
      EmergencyContact(name: (m['name'] ?? '') as String, phone: (m['phone'] ?? '') as String);
}

class PatientProfile {
  int age;
  String sex;
  bool hypertension;
  bool smoker;
  double heightCm;
  double weightKg;
  String diabetes;
  List<EmergencyContact> contacts;

  PatientProfile({
    required this.age,
    required this.sex,
    required this.hypertension,
    required this.smoker,
    required this.heightCm,
    required this.weightKg,
    required this.diabetes,
    required this.contacts,
  });

  double get bmi => heightCm > 0 ? weightKg / ((heightCm / 100) * (heightCm / 100)) : 0;

  Map<String, dynamic> toMap() => {
        'age': age,
        'sex': sex,
        'hypertension': hypertension,
        'smoker': smoker,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'diabetes': diabetes,
        'contacts': contacts.map((c) => c.toMap()).toList(),
      };

  factory PatientProfile.fromMap(Map<String, dynamic> m) => PatientProfile(
        age: (m['age'] ?? 0) as int,
        sex: (m['sex'] ?? 'Male') as String,
        hypertension: (m['hypertension'] ?? false) as bool,
        smoker: (m['smoker'] ?? false) as bool,
        heightCm: ((m['heightCm'] ?? 0) as num).toDouble(),
        weightKg: ((m['weightKg'] ?? 0) as num).toDouble(),
        diabetes: (m['diabetes'] ?? 'No') as String,
        contacts: ((m['contacts'] ?? []) as List)
            .map((c) => EmergencyContact.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
      );
}

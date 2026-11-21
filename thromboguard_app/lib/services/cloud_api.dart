import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';

class CloudResult {
  final RiskLevel risk;
  final List<String> reasons;
  final Map<String, double> ecgProbabilities;
  final String message; // short human-readable text from the server (may be empty)
  const CloudResult(this.risk, this.reasons, this.ecgProbabilities, [this.message = '']);
}

/// Thrown when the server (HTTP 422) says the ECG window is unusable
/// (flat, noisy, too short...). The app must NOT show "Normal" in this case.
class CloudSignalException implements Exception {
  final String message;
  const CloudSignalException(this.message);
  @override
  String toString() => message;
}

/// Calls the AI server (thromboguard_server, POST /analyze and POST /advice).
class CloudApi {
  /// Short safety advice (Arabic) for the medium/abnormal state. Server uses an LLM if configured, else a fixed template.
  static Future<String> advice({
    required int heartRate,
    required int spo2,
    required PatientProfile profile,
  }) async {
    final d = profile.diabetes.trim().toLowerCase();
    final body = jsonEncode({
      'level': 'abnormal',
      'heart_rate': heartRate,
      'spo2': spo2,
      'lang': 'ar',
      'profile': {
        'age': profile.age.clamp(0, 120),
        'smoker': profile.smoker,
        'diabetes': d.isNotEmpty && d != 'no' && d != 'none',
        'hypertension': profile.hypertension,
      },
    });
    final res = await http
        .post(Uri.parse('$kApiBaseUrl/advice'),
            headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Advice error ${res.statusCode}');
    }
    // Arabic text: decode bytes as UTF-8 (res.body would use latin1 when the server sends no charset).
    final m = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (m['advice'] ?? '').toString();
  }

  static Future<CloudResult> analyze({
    required List<double> ecg,
    required int heartRate,
    required int spo2, // 0 = no reading
    required bool fallDetected,
    required PatientProfile profile,
  }) async {
    final d = profile.diabetes.trim().toLowerCase();
    final body = jsonEncode({
      'ecg': ecg,
      'sampling_rate': kEcgSampleRate,
      'heart_rate': heartRate,
      'spo2': spo2,
      'fall_detected': fallDetected,
      'profile': {
        'age': profile.age.clamp(0, 120),
        'bmi': profile.bmi.clamp(10, 80),
        'smoker': profile.smoker,
        'diabetes': d.isNotEmpty && d != 'no' && d != 'none',
        'hypertension': profile.hypertension,
      },
    });
    final res = await http
        .post(Uri.parse('$kApiBaseUrl/analyze'),
            headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 422) {
      // Our server sends a plain string for an unusable ECG; a list means a malformed request (a bug, not a signal problem).
      dynamic detail;
      try {
        detail = jsonDecode(res.body)['detail'];
      } catch (_) {}
      if (detail is String) throw CloudSignalException(detail);
      throw Exception('AI server rejected the request (422): ${res.body}');
    }
    if (res.statusCode != 200) {
      throw Exception('AI server error ${res.statusCode}: ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final cls = (m['risk_class'] as num).toInt();
    final probs = <String, double>{
      for (final e in (m['ecg_probabilities'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toDouble(),
    };
    return CloudResult(
      RiskLevel.values[cls.clamp(0, 2)],
      List<String>.from(m['reasons'] as List),
      probs,
      (m['message'] ?? '').toString(),
    );
  }
}

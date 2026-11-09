import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';

class CloudResult {
  final RiskLevel risk;
  final List<String> reasons;
  final Map<String, double> ecgProbabilities;
  const CloudResult(this.risk, this.reasons, this.ecgProbabilities);
}

/// Calls the AI server (thromboguard_server, POST /analyze).
class CloudApi {
  static Future<CloudResult> analyze({
    required List<double> ecg,
    required int heartRate,
    required bool fallDetected,
    required PatientProfile profile,
  }) async {
    final d = profile.diabetes.trim().toLowerCase();
    final body = jsonEncode({
      'ecg': ecg,
      'sampling_rate': kEcgSampleRate,
      'heart_rate': heartRate,
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
    );
  }
}

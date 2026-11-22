import '../config.dart';
import '../models/models.dart';
import 'cloud_api.dart';

class Advice {
  final String text;
  final bool fromServer; // true = from the server (LLM or its template), false = built-in offline text
  const Advice(this.text, this.fromServer);
}

/// Advice shown in the MEDIUM (abnormal) state. Never blocks the app: if the server is
/// unreachable (or the simulator is on) a fixed, safe Arabic text is used instead.
class AdviceService {
  static const String _offline =
      'قراءة تخطيط القلب غير اعتيادية (هذا فحص أولي وليس تشخيصاً).\n'
      '• اجلس أو استلقِ بوضع مريح وتوقف عن أي مجهود.\n'
      '• تنفّس ببطء وعمق وحاول أن تهدأ.\n'
      '• لا تقد السيارة بنفسك.\n'
      '• أخبر شخصاً قريباً منك بما حدث.\n'
      '• راجع طبيباً اليوم ولا تؤجل.\n'
      '• إذا ظهر ألم أو ضغط في الصدر، ضيق نفس، تعرّق بارد، دوخة أو إغماء، أو ألم يمتد للذراع أو الفك، فاطلب الإسعاف فوراً.\n'
      'أعد القياس بعد بضع دقائق وأنت ساكن.';

  static Future<Advice> get({required VitalReading reading, required PatientProfile profile}) async {
    if (!kUseSimulator || kSimulatorCallsServer) {
      try {
        final t = await CloudApi.advice(heartRate: reading.heartRate, spo2: reading.spo2, profile: profile);
        if (t.trim().isNotEmpty) return Advice(t, true);
      } catch (_) {}
    }
    return const Advice(_offline, false);
  }
}

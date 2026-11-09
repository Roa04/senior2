import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/models.dart';
import '../services/emergency_service.dart';
import '../services/user_data_service.dart';
import '../theme.dart';

enum _Phase { counting, sending, done }

/// Full-screen alert shown on a Critical reading.
/// Countdown -> if the user does not press "I'M OK": SMS to ALL emergency
/// contacts (with location + vitals), then a call to the FIRST contact.
class EmergencyScreen extends StatefulWidget {
  final PatientProfile profile;
  final VitalReading reading;
  const EmergencyScreen({super.key, required this.profile, required this.reading});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _left = kCountdownSeconds;
  _Phase _phase = _Phase.counting;
  Timer? _timer;
  AlertResult? _result;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _send();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _eventData(String outcome) => {
        'outcome': outcome,
        'heartRate': widget.reading.heartRate,
        'spo2': widget.reading.spo2,
        'ecgRisk': widget.reading.risk.name,
        'readingTimestamp': widget.reading.timestamp.millisecondsSinceEpoch,
      };

  String _outcome(AlertResult r) {
    if (!r.hadContacts) return 'no_contacts';
    if (r.dryRun) return 'dry_run';
    if (r.smsSent > 0) return r.callPlaced ? 'sms_sent_and_call' : 'sms_sent';
    if (r.smsComposerOpened) return 'composer_opened';
    return 'failed';
  }

  Future<void> _send() async {
    if (_phase != _Phase.counting) return;
    _timer?.cancel();
    setState(() => _phase = _Phase.sending);
    final res = await EmergencyService.runAlert(
      profile: widget.profile,
      reading: widget.reading,
      critical: true,
      placeCall: true,
    );
    UserDataService.saveEmergency({
      ..._eventData(_outcome(res)),
      if (res.hadLocation) 'lat': res.lat,
      if (res.hadLocation) 'lng': res.lng,
    });
    if (!mounted) return;
    setState(() {
      _result = res;
      _phase = _Phase.done;
    });
  }

  void _cancel() {
    _timer?.cancel();
    UserDataService.saveEmergency(_eventData('cancelled_by_user'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.redDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_phase) {
              _Phase.counting => _counting(),
              _Phase.sending => const Center(child: CircularProgressIndicator(color: Colors.white)),
              _Phase.done => _done(),
            },
          ),
        ),
      ),
    );
  }

  Widget _counting() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5), size: 64),
        const SizedBox(height: 16),
        const Text('Possible cardiac emergency',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Heart rate ${widget.reading.heartRate} bpm  •  SpO₂ ${widget.reading.spo2}%',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 28),
        Center(
          child: Text('$_left',
              style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold)),
        ),
        const Text('Your emergency contacts will be messaged and called automatically.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.redDark,
              padding: const EdgeInsets.symmetric(vertical: 18)),
          onPressed: _cancel,
          child: const Text("I'M OK — CANCEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _send,
          child: const Text('Send alert now', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _done() {
    final r = _result!;
    final String headline;
    if (!r.hadContacts) {
      headline = 'No emergency contacts saved';
    } else if (r.dryRun) {
      headline = 'Dry run (nothing was sent)';
    } else if (r.smsSent > 0) {
      headline = 'Alert sent';
    } else if (r.smsComposerOpened) {
      headline = 'Alert ready to send';
    } else {
      headline = 'Could not send the alert';
    }
    return ListView(
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.sms_outlined, color: Colors.white, size: 56),
        const SizedBox(height: 16),
        Text(headline,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(r.summary, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        if (r.dryRun) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Text(r.message,
                textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white, height: 1.5)),
          ),
        ],
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

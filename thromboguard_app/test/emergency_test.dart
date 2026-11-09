import 'package:flutter_test/flutter_test.dart';
import 'package:thromboguard/models/models.dart';
import 'package:thromboguard/services/emergency_service.dart';

VitalReading _reading() => VitalReading(
      timestamp: DateTime(2026, 10, 10),
      heartRate: 130,
      spo2: 91,
      ppgStatus: 'Stable',
      ecg: EcgRecord(
        ecgId: 'x',
        patientId: 1,
        samplingRateHz: 100,
        leadII: const [],
        scpCodes: const {'IMI': 90.0},
        risk: RiskLevel.critical,
      ),
    );

void main() {
  test('critical message has name, vitals and a maps link', () {
    final m = EmergencyService.buildMessage(reading: _reading(), lat: 31.9, lng: 35.2, name: 'Tamara');
    expect(m, contains('Tamara'));
    expect(m, contains('130'));
    expect(m, contains('91%'));
    expect(m, contains('https://maps.google.com/?q=31.900000,35.200000'));
  });

  test('message says location unavailable when there is no GPS', () {
    final m = EmergencyService.buildMessage(reading: _reading());
    expect(m, contains('الموقع غير متوفر'));
  });

  test('abnormal wording differs from critical wording', () {
    final c = EmergencyService.buildMessage(reading: _reading(), critical: true);
    final a = EmergencyService.buildMessage(reading: _reading(), critical: false);
    expect(c, isNot(equals(a)));
    expect(c, contains('طوارئ'));
  });

  test('contact numbers are cleaned and empty ones dropped', () {
    final nums = EmergencyService.contactNumbers([
      EmergencyContact(name: 'Dad', phone: '059 964-6320'),
      EmergencyContact(name: 'Empty', phone: '  '),
    ]);
    expect(nums, ['0599646320']);
  });

  test('first contact skips entries without a number', () {
    final c = EmergencyService.firstContact([
      EmergencyContact(name: 'Empty', phone: ''),
      EmergencyContact(name: 'Dad', phone: '0599646320'),
      EmergencyContact(name: 'Mom', phone: '0591111111'),
    ]);
    expect(c?.name, 'Dad');
  });

  test('sms uri encodes the body', () {
    final u = EmergencyService.smsUri(['0599646320'], 'a b');
    expect(u.toString(), 'sms:0599646320?body=a%20b');
  });
}

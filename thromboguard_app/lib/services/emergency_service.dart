import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models/models.dart';
import 'user_data_service.dart';

class AlertResult {
  final bool dryRun;
  final bool hadContacts;
  final int contactCount;
  final int smsSent; // sent silently by the app (Android)
  final bool smsComposerOpened; // fallback: SMS app opened, user presses Send
  final bool callPlaced;
  final String? calledName;
  final double? lat;
  final double? lng;
  final String message;

  const AlertResult({
    required this.dryRun,
    required this.hadContacts,
    required this.contactCount,
    required this.smsSent,
    required this.smsComposerOpened,
    required this.callPlaced,
    required this.calledName,
    required this.lat,
    required this.lng,
    required this.message,
  });

  bool get hadLocation => lat != null && lng != null;

  String get summary {
    if (!hadContacts) return 'No emergency contacts saved. Add one in Profile.';
    if (dryRun) {
      return 'DRY RUN: would alert $contactCount contact(s)'
          '${calledName != null ? ' and call $calledName' : ''}.';
    }
    if (smsSent > 0) {
      return 'SMS sent to $smsSent contact(s)${callPlaced ? ' and calling $calledName' : ''}.';
    }
    if (smsComposerOpened) return 'Alert message is ready in your SMS app. Press Send.';
    return 'Could not send the alert.';
  }
}

class EmergencyService {
  static const MethodChannel _channel = MethodChannel('thromboguard/emergency');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ---------------- permissions ----------------

  static Future<bool> hasPhonePermissions() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasPermissions') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// SMS + call (native) and location. Call once, at first launch.
  static Future<void> requestAllPermissions() async {
    if (_isAndroid) {
      try {
        await _channel.invokeMethod<bool>('requestPermissions');
      } catch (_) {}
    }
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) await Geolocator.requestPermission();
    } catch (_) {}
  }

  // ---------------- location ----------------

  /// Best-effort location: never throws, returns null if unavailable/denied.
  static Future<Position?> getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // ---------------- message + contacts ----------------

  /// Arabic, gender-neutral. [critical] = emergency wording, otherwise a
  /// softer "readings are abnormal" wording.
  static String buildMessage({
    required VitalReading reading,
    double? lat,
    double? lng,
    String? name,
    bool critical = true,
  }) {
    final who = (name == null || name.trim().isEmpty) ? 'المريض' : name.trim();
    final b = StringBuffer();
    if (critical) {
      b.write('تنبيه طوارئ من ThromboGuard: حالة طوارئ قلبية محتملة لدى $who.');
    } else {
      b.write('تنبيه من ThromboGuard: قراءات القلب لدى $who غير طبيعية.');
    }
    b.write('\nالنبض ${reading.heartRate}، الأكسجين ${reading.spo2}%.');
    if (lat != null && lng != null) {
      b.write('\nالموقع: https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}');
    } else {
      b.write('\nالموقع غير متوفر.');
    }
    b.write(critical ? '\nيرجى الاتصال فوراً أو طلب الإسعاف.' : '\nيرجى الاطمئنان.');
    return b.toString();
  }

  static String cleanNumber(String p) => p.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  static List<String> contactNumbers(List<EmergencyContact> contacts) =>
      contacts.map((c) => cleanNumber(c.phone)).where((p) => p.isNotEmpty).toList();

  static EmergencyContact? firstContact(List<EmergencyContact> contacts) {
    for (final c in contacts) {
      if (cleanNumber(c.phone).isNotEmpty) return c;
    }
    return null;
  }

  static Uri smsUri(List<String> numbers, String body) {
    final sep = defaultTargetPlatform == TargetPlatform.iOS ? ',' : ';';
    return Uri.parse('sms:${numbers.join(sep)}?body=${Uri.encodeComponent(body)}');
  }

  // ---------------- the alert ----------------

  /// 1) location  2) SMS to ALL contacts  3) call the FIRST contact.
  /// SMS goes first because once a call starts Android moves the app to the
  /// background. On Android with permissions everything is automatic; on
  /// other platforms it falls back to opening the SMS app.
  static Future<AlertResult> runAlert({
    required PatientProfile profile,
    required VitalReading reading,
    required bool critical,
    required bool placeCall,
  }) async {
    final pos = await getLocation();
    String? name;
    try {
      name = await UserDataService.loadUsername();
    } catch (_) {}
    final msg = buildMessage(
        reading: reading, lat: pos?.latitude, lng: pos?.longitude, name: name, critical: critical);
    final numbers = contactNumbers(profile.contacts);
    final first = firstContact(profile.contacts);

    AlertResult result({
      bool dryRun = false,
      int sent = 0,
      bool composer = false,
      bool called = false,
      String? calledName,
    }) =>
        AlertResult(
          dryRun: dryRun,
          hadContacts: numbers.isNotEmpty,
          contactCount: numbers.length,
          smsSent: sent,
          smsComposerOpened: composer,
          callPlaced: called,
          calledName: calledName,
          lat: pos?.latitude,
          lng: pos?.longitude,
          message: msg,
        );

    if (numbers.isEmpty) return result();
    if (kEmergencyDryRun) {
      return result(dryRun: true, calledName: placeCall ? first?.name : null);
    }

    var sent = 0;
    var composer = false;
    if (_isAndroid && await hasPhonePermissions()) {
      try {
        sent = await _channel.invokeMethod<int>('sendSms', {'numbers': numbers, 'message': msg}) ?? 0;
      } catch (_) {
        sent = 0;
      }
    }
    if (sent == 0) {
      try {
        composer = await launchUrl(smsUri(numbers, msg));
      } catch (_) {
        composer = false;
      }
    }

    var called = false;
    if (placeCall && first != null && !composer) {
      called = await _call(cleanNumber(first.phone));
    }
    return result(sent: sent, composer: composer, called: called, calledName: called ? first?.name : null);
  }

  static Future<bool> _call(String number) async {
    if (_isAndroid && await hasPhonePermissions()) {
      try {
        return await _channel.invokeMethod<bool>('call', {'number': number}) ?? false;
      } catch (_) {
        return false;
      }
    }
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      return false;
    }
  }
}

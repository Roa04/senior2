import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/models.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/emergency_screen.dart';
import '../config.dart';
import '../services/ble_reading_source.dart';
import '../services/emergency_service.dart';
import '../services/ptbxl_service.dart';
import '../services/reading_source.dart';
import '../services/user_data_service.dart';

class BottomNavShell extends StatefulWidget {
  final PatientProfile profile;

  /// Where readings come from. Defaults to the simulator; pass the BLE/cloud
  /// source here later without touching any screen.
  final ReadingSource? source;
  const BottomNavShell({super.key, required this.profile, this.source});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;
  late PatientProfile _profile;
  final List<VitalReading> _log = [];
  VitalReading? _current;

  // Reading source (simulated for now; BLE + cloud model later).
  late final ReadingSource _service;
  StreamSubscription<VitalReading>? _sub;

  // Emergency: one countdown per episode, then a cool-down so a persistent
  // Critical state does not re-trigger it every few seconds.
  static const Duration _emergencyCooldown = Duration(minutes: 5);
  static const Duration _abnormalCooldown = Duration(minutes: 30);
  bool _emergencyActive = false;
  DateTime _lastAbnormalAlert = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastEmergency = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastNormalSave = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _service = widget.source ??
        (kUseSimulator ? PtbxlService() : BleReadingSource(profile: () => _profile));
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
    _sub = _service.readings.listen(_onReading);
    _service.start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    super.dispose();
  }

  /// Explains why the permissions are needed, then asks for all of them at
  /// the first launch (asking during an emergency would be too late).
  Future<void> _askPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (await EmergencyService.hasPhonePermissions()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency permissions'),
        content: const Text(
            'ThromboGuard needs permission to send SMS, place a call and read your location, '
            'so it can alert your emergency contacts automatically if a critical heart event is detected.'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Continue'))],
      ),
    );
    await EmergencyService.requestAllPermissions();
  }

  /// Abnormal (not critical): SMS to the family only, at most once per 30 min.
  Future<void> _maybeAlertAbnormal(VitalReading r) async {
    if (_emergencyActive || DateTime.now().difference(_lastAbnormalAlert) < _abnormalCooldown) return;
    _lastAbnormalAlert = DateTime.now();
    final res = await EmergencyService.runAlert(
        profile: _profile, reading: r, critical: false, placeCall: false);
    UserDataService.saveEmergency({
      'outcome': res.dryRun ? 'abnormal_dry_run' : (res.smsSent > 0 ? 'abnormal_sms_sent' : 'abnormal_failed'),
      'heartRate': r.heartRate,
      'spo2': r.spo2,
      'ecgRisk': r.risk.name,
      'readingTimestamp': r.timestamp.millisecondsSinceEpoch,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abnormal reading. ${res.summary}')));
  }

  Future<void> _maybeStartEmergency(VitalReading r) async {
    if (_emergencyActive || DateTime.now().difference(_lastEmergency) < _emergencyCooldown) return;
    _emergencyActive = true;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EmergencyScreen(profile: _profile, reading: r),
    ));
    _lastEmergency = DateTime.now();
    _emergencyActive = false;
  }

  Future<void> _loadHistory() async {
    try {
      final old = await UserDataService.loadRecentReadings();
      if (!mounted) return;
      setState(() {
        // Keep anything that arrived while loading at the top.
        _log.addAll(old);
        if (_log.length > 50) _log.removeRange(50, _log.length);
      });
    } catch (_) {
      // Offline / no history yet: start with an empty log.
    }
  }

  void _onReading(VitalReading r) {
    if (!mounted) return;
    setState(() {
      _current = r;
      _log.insert(0, r);
      if (_log.length > 50) _log.removeLast();
    });
    if (r.risk == RiskLevel.critical) _maybeStartEmergency(r);
    if (r.risk == RiskLevel.abnormal) _maybeAlertAbnormal(r);

    // Save every non-normal reading; normal ones at most once per 5 minutes
    // (the simulator fires every 4 s, which would flood Firestore).
    final now = DateTime.now();
    if (r.risk != RiskLevel.normal) {
      UserDataService.saveReading(r);
    } else if (now.difference(_lastNormalSave) > const Duration(minutes: 5)) {
      _lastNormalSave = now;
      UserDataService.saveReading(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = r() ;
    final pages = [
      HomeScreen(profile: _profile, current: _current),
      HistoryScreen(log: _log),
      ProfileScreen(profile: _profile),
    ];

    return Scaffold(
      backgroundColor: _current?.risk == RiskLevel.critical && _index == 0
          ? const Color(0xFFFEF2F2)
          : AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          if (_service is BleReadingSource)
            _BleBanner(source: _service as BleReadingSource),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, -4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home, label: 'Home', selected: _index == 0, onTap: () => setState(() => _index = 0), activeColor: active),
            _NavItem(icon: Icons.history, label: 'History', selected: _index == 1, onTap: () => setState(() => _index = 1), activeColor: active),
            _NavItem(icon: Icons.person, label: 'Profile', selected: _index == 2, onTap: () => setState(() => _index = 2), activeColor: active),
          ],
        ),
      ),
    );
  }

  Color r() {
    if (_current?.risk == RiskLevel.critical) return AppColors.red;
    return AppColors.blue;
  }
}

/// Wristband / server status strip (FR-02: "Device Disconnected").
class _BleBanner extends StatelessWidget {
  final BleReadingSource source;
  const _BleBanner({required this.source});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleStatus>(
      valueListenable: source.status,
      builder: (context, s, _) => ValueListenableBuilder<String?>(
        valueListenable: source.cloudError,
        builder: (context, err, _) {
          String? text;
          Color color = Colors.orange;
          switch (s) {
            case BleStatus.bluetoothOff:
              text = 'Bluetooth is off. Turn it on to connect the wristband.';
              color = Colors.red;
            case BleStatus.scanning:
              text = 'Searching for the wristband...';
            case BleStatus.connecting:
              text = 'Connecting to the wristband...';
            case BleStatus.disconnected:
              text = 'Device Disconnected. Reconnecting...';
              color = Colors.red;
            case BleStatus.connected:
              if (err != null) text = err;
          }
          if (text == null) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : AppColors.mutedGrey;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}

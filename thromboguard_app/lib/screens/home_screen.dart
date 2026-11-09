import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/ptbxl_service.dart';

/// Stateless: the reading stream is owned by BottomNavShell so switching
/// tabs no longer restarts it.
class HomeScreen extends StatelessWidget {
  final PatientProfile? profile;
  final VitalReading? current;

  const HomeScreen({super.key, required this.profile, required this.current});

  @override
  Widget build(BuildContext context) {
    final r = current;
    if (r == null) return const Center(child: CircularProgressIndicator());
    final tip = PtbxlService.generateHealthTip(r);

    switch (r.risk) {
      case RiskLevel.normal:
        return _NormalHome(r: r, tip: tip);
      case RiskLevel.abnormal:
        return _AbnormalHome(r: r, tip: tip);
      case RiskLevel.critical:
        return _CriticalHome(r: r, tip: tip);
    }
  }
}

// ---------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------

class _RiskBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final Color bg;
  final Color border;
  final Color titleColor;
  final Color subtitleColor;
  final Color tagBg;

  const _RiskBanner({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.subtitleColor,
    required this.tagBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: border, width: 5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
            child: Text(tag,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool alert;
  const _VitalRow({required this.icon, required this.label, required this.value, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert ? const Color(0xFFFFF5F5) : AppColors.bgCard,
        border: Border.all(color: alert ? const Color(0xFFFCA5A5) : AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: alert ? AppColors.red : AppColors.blue),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Color(0xFF4A5568), fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          Text(value,
              style: TextStyle(
                  color: alert ? const Color(0xFFB91C1C) : AppColors.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.navy),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  final String title;
  final String body;
  final Color borderColor;
  final Color bg;
  final Color titleColor;
  final Color bodyColor;
  const _AiCard({
    required this.title,
    required this.body,
    required this.borderColor,
    required this.bg,
    required this.titleColor,
    required this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(color: bodyColor, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Normal
// ---------------------------------------------------------------------
class _NormalHome extends StatelessWidget {
  final VitalReading r;
  final String tip;
  const _NormalHome({required this.r, required this.tip});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _RiskBanner(
          title: 'Normal Health Status',
          subtitle: 'Checked a few seconds ago',
          tag: 'Optimal',
          bg: AppColors.greenBg,
          border: AppColors.green,
          titleColor: AppColors.greenText,
          subtitleColor: Color(0xFF047857),
          tagBg: AppColors.green,
        ),
        _Panel(
          title: 'LIVE METRICS',
          icon: Icons.monitor_heart_outlined,
          child: Column(children: [
            _VitalRow(icon: Icons.favorite, label: 'Heart Rate', value: '${r.heartRate} bpm'),
            _VitalRow(icon: Icons.air, label: 'SpO₂ Oxygen', value: '${r.spo2} %'),
            _VitalRow(icon: Icons.fingerprint, label: 'PPG Stream', value: r.ppgStatus),
            _VitalRow(icon: Icons.show_chart, label: 'ECG Trace', value: r.risk.label),
          ]),
        ),
        _Panel(
          title: 'AI HEALTH INSIGHTS',
          icon: Icons.smart_toy_outlined,
          child: _AiCard(
            title: 'Excellent Core Stability',
            body: tip,
            borderColor: AppColors.blue,
            bg: const Color(0xFFF0F7FF),
            titleColor: AppColors.navy,
            bodyColor: const Color(0xFF4A5568),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Abnormal
// ---------------------------------------------------------------------
class _AbnormalHome extends StatelessWidget {
  final VitalReading r;
  final String tip;
  const _AbnormalHome({required this.r, required this.tip});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _RiskBanner(
          title: 'Abnormal Profile Risk',
          subtitle: 'Evaluated a few seconds ago',
          tag: 'Abnormal',
          bg: AppColors.amberBg,
          border: AppColors.amber,
          titleColor: AppColors.amberText,
          subtitleColor: Color(0xFFD97706),
          tagBg: AppColors.amber,
        ),
        _Panel(
          title: 'VITAL SIGNS',
          icon: Icons.monitor_heart_outlined,
          child: Column(children: [
            _VitalRow(icon: Icons.favorite, label: 'Heart Rate', value: '${r.heartRate} bpm'),
            _VitalRow(icon: Icons.air, label: 'SpO₂ Oxygen', value: '${r.spo2} %'),
            _VitalRow(icon: Icons.fingerprint, label: 'PPG Stream', value: r.ppgStatus),
            _VitalRow(icon: Icons.show_chart, label: 'ECG Trace', value: r.ecg.scpCodes.keys.first),
          ]),
        ),
        _Panel(
          title: 'AI HEALTH INSIGHTS',
          icon: Icons.smart_toy_outlined,
          child: _AiCard(
            title: 'Elevated Cardiac Signal',
            body: tip,
            borderColor: AppColors.blue,
            bg: const Color(0xFFF0F7FF),
            titleColor: AppColors.navy,
            bodyColor: const Color(0xFF4A5568),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Critical
// ---------------------------------------------------------------------
class _CriticalHome extends StatelessWidget {
  final VitalReading r;
  final String tip;
  const _CriticalHome({required this.r, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF2F2),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _RiskBanner(
            title: 'Critical Profile Risk',
            subtitle: 'Evaluated Just Now',
            tag: 'Critical',
            bg: AppColors.redBg,
            border: AppColors.red,
            titleColor: AppColors.redText,
            subtitleColor: Color(0xFFB91C1C),
            tagBg: AppColors.red,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.redDark, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5)),
                  SizedBox(width: 10),
                  Text('Cardiac Distress Warning',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                SizedBox(height: 10),
                Text(
                  'Your recorded vitals have passed critical thresholds. Please sit down immediately. Your emergency contacts are being alerted automatically.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          _Panel(
            title: 'LIVE METRICS',
            icon: Icons.monitor_heart_outlined,
            child: Column(children: [
              _VitalRow(icon: Icons.favorite, label: 'Heart Rate', value: '${r.heartRate} bpm', alert: true),
              _VitalRow(icon: Icons.air, label: 'SpO₂ Oxygen', value: '${r.spo2} %', alert: true),
              _VitalRow(icon: Icons.fingerprint, label: 'PPG Stream', value: r.ppgStatus, alert: true),
              _VitalRow(icon: Icons.show_chart, label: 'ECG Trace', value: r.ecg.scpCodes.keys.first, alert: true),
            ]),
          ),
          _Panel(
            title: 'AI TRIAGE RECOMMENDATION',
            icon: Icons.smart_toy_outlined,
            child: _AiCard(
              title: 'Possible Myocardial Infarction',
              body: tip,
              borderColor: AppColors.red,
              bg: AppColors.redBg,
              titleColor: AppColors.redText,
              bodyColor: AppColors.redDark,
            ),
          ),
        ],
      ),
    );
  }
}

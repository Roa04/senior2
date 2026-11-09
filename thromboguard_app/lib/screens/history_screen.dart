import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/models.dart';

class HistoryScreen extends StatelessWidget {
  final List<VitalReading> log;
  const HistoryScreen({super.key, required this.log});

  Color _borderColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.normal:
        return AppColors.green;
      case RiskLevel.abnormal:
        return AppColors.amber;
      case RiskLevel.critical:
        return AppColors.red;
    }
  }

  Color _badgeBg(RiskLevel r) {
    switch (r) {
      case RiskLevel.normal:
        return AppColors.greenBg;
      case RiskLevel.abnormal:
        return AppColors.amberBg;
      case RiskLevel.critical:
        return AppColors.redBg;
    }
  }

  Color _badgeText(RiskLevel r) {
    switch (r) {
      case RiskLevel.normal:
        return AppColors.green;
      case RiskLevel.abnormal:
        return AppColors.amber;
      case RiskLevel.critical:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text('READINGS LOG',
              style: TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        if (log.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No readings yet'))),
        ...log.asMap().entries.map((e) {
          final index = log.length - e.key;
          final r = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border(left: BorderSide(color: _borderColor(r.risk), width: 5)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('#${index.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _badgeBg(r.risk), borderRadius: BorderRadius.circular(20)),
                      child: Text(r.risk.label.toUpperCase(),
                          style: TextStyle(color: _badgeText(r.risk), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 10,
                  childAspectRatio: 5,
                  children: [
                    _Detail('Heart Rate', '${r.heartRate} bpm'),
                    _Detail('SpO₂', '${r.spo2}%'),
                    _Detail('PPG Wave', r.ppgStatus),
                    _Detail('ECG Status', r.ecg.scpCodes.keys.first,
                        color: r.risk == RiskLevel.normal ? AppColors.green : AppColors.red),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Detail(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.grey, fontSize: 12),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
              text: value,
              style: TextStyle(color: color ?? AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

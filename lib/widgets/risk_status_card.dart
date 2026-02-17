// ===============================
// RISK FACTOR CARD
// ===============================
// Shows current risk level clearly
// ===============================

import 'package:flutter/material.dart';
import '../models/risk_level.dart';

class RiskStatusCard extends StatelessWidget {
  final RiskLevel riskLevel;

  const RiskStatusCard({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: riskLevel.color),
        title: const Text(
          'Risk Factor',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          riskLevel.label,
          style: TextStyle(color: riskLevel.color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

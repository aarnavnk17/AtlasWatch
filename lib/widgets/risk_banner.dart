import 'package:flutter/material.dart';
import '../models/risk_level.dart';

class RiskBanner extends StatelessWidget {
  final RiskLevel riskLevel;

  const RiskBanner({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String text;
    IconData icon;

    switch (riskLevel) {
      case RiskLevel.high:
        bg = Colors.red;
        text = 'High risk area';
        icon = Icons.warning;
        break;
      case RiskLevel.medium:
        bg = Colors.orange;
        text = 'Medium risk area';
        icon = Icons.report;
        break;
      default:
        bg = Colors.green;
        text = 'Low risk area';
        icon = Icons.check_circle;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(16),
      color: bg,
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// SOS BUTTON WITH CONFIRMATION
// ===============================

import 'package:flutter/material.dart';
import '../screens/sos_active_screen.dart';

class SosButton extends StatelessWidget {
  const SosButton({super.key});

  void _showSosConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm SOS'),
        content: const Text(
          'Are you sure you want to activate SOS?\nThis action should only be used in emergencies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SosActiveScreen()),
              );
            },
            child: const Text('Activate SOS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _showSosConfirmation(context),
      child: const Text('SOS', style: TextStyle(fontSize: 16)),
    );
  }
}

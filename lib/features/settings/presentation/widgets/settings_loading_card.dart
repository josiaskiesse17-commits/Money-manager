import 'package:flutter/material.dart';

import 'package:money_manager/app/widgets/app_card.dart';

/// Loading placeholder used while a settings section is being fetched.
class SettingsLoadingCard extends StatelessWidget {
  final String message;

  const SettingsLoadingCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

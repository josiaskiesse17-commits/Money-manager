import 'package:flutter/material.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';

/// Error banner: what went wrong + how to fix it, never vague.
class ErrorBanner extends StatelessWidget {
  final String message;
  final String? fix;
  final VoidCallback? onRetry;

  const ErrorBanner({super.key, required this.message, this.fix, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (fix != null) ...[
            const SizedBox(height: 8),
            Text(
              fix!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SecondaryButton(text: 'Retry', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

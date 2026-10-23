import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

/// Shows a confirmation dialog, deletes the transaction, and shows an Undo SnackBar.
/// Returns true if the deletion was confirmed (regardless of whether Undo was tapped).
Future<bool> deleteTransactionWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required String uid,
  required Transaction transaction,
  required String categoryName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Delete transaction?'),
      content: Text(
        'This $categoryName transaction will be deleted. '
        'You can undo within a few seconds.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    await ref.read(transactionProvider(uid).notifier).delete(transaction);

    if (!context.mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted successfully.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(
              ref.read(transactionProvider(uid).notifier).restore(transaction),
            );
          },
        ),
      ),
    );

    return true;
  } catch (_) {
    if (!context.mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not delete the transaction. Please try again.'),
      ),
    );

    return false;
  }
}

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/models/debt_payment.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/debts/application/debt_provider.dart';
import 'package:money_manager/features/debts/presentation/add_payment_sheet.dart';

/// Debt detail screen: header, payment history, edit/archive actions.
class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final debtsAsync = ref.watch(debtProvider(uid));
    final paymentsAsync = ref.watch(debtPaymentsProvider(debtId));
    final theme = Theme.of(context);

    return ResponsiveBody(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              debtsAsync.when(
                loading: () => const _LoadingState(),
                error: (error, stackTrace) => ErrorBanner(
                  message: 'Could not load debt.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(debtProvider(uid)),
                ),
                data: (debts) {
                  final debt = debts.firstWhereOrNull((d) => d.id == debtId);
                  if (debt == null) {
                    return const _ErrorState(message: 'Debt not found.');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(debt: debt),
                      const SizedBox(height: 16),
                      _Actions(debt: debt, uid: uid, ref: ref, debtId: debtId),
                      const SizedBox(height: 24),
                      Text(
                        'Payments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      paymentsAsync.when(
                        loading: () => const _LoadingState(),
                        error: (error, stackTrace) => ErrorBanner(
                          message: 'Could not load payments.',
                          fix: 'Check your connection and try again.',
                          onRetry: () =>
                              ref.refresh(debtPaymentsProvider(debtId)),
                        ),
                        data: (payments) {
                          if (payments.isEmpty) {
                            return EmptyState(
                              icon: Icons.payment_outlined,
                              title: 'No payments yet',
                              subtitle: 'Record your first payment below.',
                              action: SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  text: 'Add payment',
                                  icon: Icons.add_rounded,
                                  onPressed: () =>
                                      _openAddPaymentSheet(context, debt),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: payments
                                .map(
                                  (payment) => _PaymentRow(
                                    payment: payment,
                                    debt: debt,
                                    onDelete: () => _confirmDeletePayment(
                                      context,
                                      ref,
                                      debt,
                                      payment,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (paymentsAsync.value?.isNotEmpty == true)
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            text: 'Add payment',
                            icon: Icons.add_rounded,
                            onPressed: () =>
                                _openAddPaymentSheet(context, debt),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddPaymentSheet(BuildContext context, Debt debt) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      showDialog<void>(
        context: context,
        builder: (_) => AddPaymentSheet(debt: debt),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddPaymentSheet(debt: debt),
    );
  }

  Future<void> _confirmDeletePayment(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
    DebtPayment payment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
          'This will reverse the wallet and remaining balance for "${debt.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            text: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final currentUid = ref.read(authProvider)?.uid ?? '';
      if (currentUid.isNotEmpty) {
        await ref
            .read(debtProvider(currentUid).notifier)
            .deletePayment(debt, payment);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid = debt.principal - debt.remaining;
    final progress = debt.principal > 0
        ? (paid / debt.principal).clamp(0.0, 1.0)
        : 0.0;
    final settled = debt.remaining == 0;
    final overdue =
        debt.dueDate != null &&
        debt.remaining > 0 &&
        debt.dueDate!.isBefore(DateTime.now());

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  debt.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (settled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Settled',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (debt.direction == 'owe'
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  debt.direction == 'owe' ? 'You owe' : 'Owed to you',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: debt.direction == 'owe'
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                debt.currency,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Principal',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      amount: debt.principal,
                      currency: debt.currency,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      amount: debt.remaining,
                      currency: debt.currency,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                settled
                    ? Theme.of(context).colorScheme.primary
                    : (overdue
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$paid paid of ${_formatMinor(debt.principal, debt.currency)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (debt.dueDate != null) ...[
                const SizedBox(width: 16),
                Icon(
                  overdue ? Icons.warning_amber_rounded : Icons.calendar_today,
                  size: 16,
                  color: overdue
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('MMM d, yyyy').format(debt.dueDate!)}${overdue ? '  ·  overdue' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: overdue
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
          if (debt.note?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              debt.note!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.debt,
    required this.uid,
    required this.ref,
    required this.debtId,
  });

  final Debt debt;
  final String uid;
  final WidgetRef ref;
  final String debtId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settled = debt.remaining == 0;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openEditDialog(context, ref, debt, uid),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: settled ? 'Unarchive' : 'Archive',
                  onPressed: () => _confirmArchive(context, ref, uid, debt),
                ),
              ),
            ],
          ),
          if (settled) ...[
            const SizedBox(height: 12),
            Text(
              'This debt is fully paid. Archiving keeps the record without affecting balances.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
    String uid,
  ) async {
    final nameCtrl = TextEditingController(text: debt.name);
    final noteCtrl = TextEditingController(text: debt.note ?? '');
    DateTime? dueDate = debt.dueDate;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit debt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null && context.mounted) {
                          dueDate = picked;
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        dueDate == null
                            ? 'Due date'
                            : DateFormat('MMM d, yyyy').format(dueDate!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            text: 'Save',
            onPressed: nameCtrl.text.trim().isNotEmpty
                ? () => _saveEdit(
                    ref: ref,
                    debt: debt,
                    uid: uid,
                    nameCtrl: nameCtrl,
                    noteCtrl: noteCtrl,
                    dueDate: dueDate,
                    dialogContext: context,
                    screenContext: context,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _saveEdit({
    required WidgetRef ref,
    required Debt debt,
    required String uid,
    required TextEditingController nameCtrl,
    required TextEditingController noteCtrl,
    required DateTime? dueDate,
    required BuildContext dialogContext,
    required BuildContext screenContext,
  }) async {
    final updated = debt.copyWith(
      name: nameCtrl.text.trim(),
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      dueDate: dueDate,
    );
    await ref.read(debtProvider(uid).notifier).updateDebt(updated);
    if (screenContext.mounted) {
      Navigator.of(dialogContext).pop(true);
    }
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    String uid,
    Debt debt,
  ) async {
    final verb = debt.archived ? 'Unarchive' : 'Archive';
    final settled = debt.remaining == 0;
    final confirmed = !settled
        ? await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('$verb debt?'),
              content: const Text(
                'Archiving an unsettled debt keeps the record but stops it from appearing in active lists.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                PrimaryButton(
                  text: verb,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          )
        : true;
    if (confirmed == true && context.mounted) {
      await ref
          .read(debtProvider(uid).notifier)
          .archiveDebt(debtId, !debt.archived);
    }
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.debt,
    required this.onDelete,
  });

  final DebtPayment payment;
  final Debt debt;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          _formatMinor(payment.amount, payment.currency),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(payment.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (payment.note?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                payment.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          tooltip: 'Delete payment',
        ),
      ),
    );
  }
}

String _formatMinor(int amount, String currency) {
  switch (currency) {
    case 'USD':
      final dollars = amount ~/ 100;
      final cents = amount % 100;
      return '\$$dollars.${cents.toString().padLeft(2, '0')}';
    case 'CDF':
      return '$amount FC';
    default:
      return '$amount';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message)]),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

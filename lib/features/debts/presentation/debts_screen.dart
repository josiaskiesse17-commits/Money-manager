import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/debts/application/debt_provider.dart';
import 'package:money_manager/features/debts/presentation/add_debt_sheet.dart';

/// Debts list screen: track money you owe or are owed, per currency.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _directionFilter = 'all'; // all | owe | owed
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final debtsAsync = ref.watch(debtProvider(uid));
    final theme = Theme.of(context);

    return ResponsiveBody(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Track money you owe or are owed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              debtsAsync.when(
                loading: () => const _LoadingState(),
                error: (error, stackTrace) => ErrorBanner(
                  message: 'Could not load debts.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(debtProvider(uid)),
                ),
                data: (debts) {
                  final active = debts.where((d) => !d.archived).toList();
                  final archived = debts.where((d) => d.archived).toList();
                  final showList = _showArchived ? archived : active;
                  final filtered =
                      showList.where((d) {
                        switch (_directionFilter) {
                          case 'owe':
                            return d.direction == 'owe';
                          case 'owed':
                            return d.direction == 'owed';
                          default:
                            return true;
                        }
                      }).toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DirectionFilter(
                        value: _directionFilter,
                        onChanged: (v) =>
                            setState(() => _directionFilter = v ?? 'all'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Switch(
                            value: _showArchived,
                            onChanged: (v) => setState(() => _showArchived = v),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _showArchived
                                  ? 'Show archived debts'
                                  : 'Show active debts',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TotalsSection(debts: active),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        _EmptyDebts(
                          archived: _showArchived,
                          oweCount: active
                              .where((d) => d.direction == 'owe')
                              .length,
                          owedCount: active
                              .where((d) => d.direction == 'owed')
                              .length,
                        )
                      else
                        ...filtered.map(
                          (debt) => _DebtRow(
                            debt: debt,
                            onTap: () => context.go(
                              AppRoutes.debtDetail.replaceAll(':id', debt.id),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          text: 'Add debt',
                          icon: Icons.add_rounded,
                          onPressed: () => _openAddDebtSheet(context),
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

  void _openAddDebtSheet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      showDialog<void>(context: context, builder: (_) => const AddDebtSheet());
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddDebtSheet(),
    );
  }
}

class _DirectionFilter extends StatelessWidget {
  const _DirectionFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment(
          value: 'all',
          label: Text('All'),
          icon: Icon(Icons.list_rounded),
        ),
        ButtonSegment(
          value: 'owe',
          label: Text('I owe'),
          icon: Icon(Icons.payment_rounded),
        ),
        ButtonSegment(
          value: 'owed',
          label: Text('Owed to me'),
          icon: Icon(Icons.account_balance_wallet_rounded),
        ),
      ],
      selected: <String>{value},
      onSelectionChanged: (selection) =>
          onChanged(selection.isNotEmpty ? selection.first : 'all'),
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.debts});

  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDirectionCurrency = <String, int>{};
    for (final d in debts) {
      final key = '${d.direction}|${d.currency}';
      byDirectionCurrency[key] = (byDirectionCurrency[key] ?? 0) + d.remaining;
    }

    final keys = byDirectionCurrency.keys.toList()..sort();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total remaining',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (keys.isEmpty)
            Text(
              'No debts yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: keys.map((key) {
                final parts = key.split('|');
                final direction = parts[0];
                final currency = parts[1];
                final amount = byDirectionCurrency[key]!;
                final label = direction == 'owe' ? 'You owe' : 'Owed to you';
                return _TotalChip(
                  label: label,
                  currency: currency,
                  amount: amount,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.currency,
    required this.amount,
  });

  final String label;
  final String currency;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          AmountText(
            amount: amount,
            currency: currency,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.onTap});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moneyColors = Theme.of(context).extension<MoneyColors>();
    final paid = debt.principal - debt.remaining;
    final progress = debt.principal > 0
        ? (paid / debt.principal).clamp(0.0, 1.0)
        : 0.0;
    final overdue =
        debt.dueDate != null &&
        debt.remaining > 0 &&
        debt.dueDate!.isBefore(DateTime.now());

    final dueText = debt.dueDate != null
        ? DateFormat('MMM d, yyyy').format(debt.dueDate!)
        : null;

    final directionLabel = debt.direction == 'owe' ? 'You owe' : 'Owed to you';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (debt.direction == 'owe'
                                  ? moneyColors?.expense
                                  : moneyColors?.income)
                              ?.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      directionLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: debt.direction == 'owe'
                            ? moneyColors?.expense
                            : moneyColors?.income,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Principal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(debt.principal, debt.currency),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overdue
                        ? theme.colorScheme.error
                        : (progress >= 1.0
                              ? moneyColors?.income ?? theme.colorScheme.primary
                              : theme.colorScheme.primary),
                  ),
                ),
              ),
              if (dueText != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today,
                      size: 16,
                      color: overdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$dueText${overdue ? '  ·  overdue' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: overdue
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCurrency(int amount, String currency) {
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

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts({
    required this.archived,
    required this.oweCount,
    required this.owedCount,
  });

  final bool archived;
  final int oweCount;
  final int owedCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            archived ? Icons.archive_outlined : Icons.attach_money,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            archived ? 'No archived debts' : 'No debts yet',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            archived ? 'Archived debts will appear here.' : 'You have not recorded any debts yet. Add your first debt below.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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

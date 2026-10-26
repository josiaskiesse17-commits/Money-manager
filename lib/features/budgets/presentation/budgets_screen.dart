import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';
import 'package:money_manager/features/budgets/presentation/budget_dialog.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider)?.uid;
    final selectedMonth = ref.watch(selectedMonthProvider);
    final theme = Theme.of(context);

    if (uid == null || uid.isEmpty) {
      return const Center(
        child: Text('Please sign in to manage your budgets.'),
      );
    }

    final budgetsAsync = ref.watch(budgetProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    return ResponsiveBody(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: 24),
              _buildMonthBanner(context, selectedMonth),
              const SizedBox(height: 24),
              budgetsAsync.when(
                loading: () => const _LoadingState(),
                error: (error, stackTrace) => _ErrorState(
                  message: 'Could not load your budgets.',
                  onRetry: () {
                    ref.invalidate(budgetProvider(uid));
                  },
                ),
                data: (budgets) {
                  return categoriesAsync.when(
                    loading: () => const _LoadingState(),
                    error: (error, stackTrace) => _ErrorState(
                      message: 'Could not load your categories.',
                      onRetry: () {
                        ref.invalidate(categoryProvider(uid));
                      },
                    ),
                    data: (categories) {
                      return transactionsAsync.when(
                        loading: () => const _LoadingState(),
                        error: (error, stackTrace) => _ErrorState(
                          message: 'Could not load your transactions.',
                          onRetry: () {
                            ref.invalidate(transactionProvider(uid));
                          },
                        ),
                        data: (transactions) {
                          return settingsAsync.when(
                            loading: () => const _LoadingState(),
                            error: (error, stackTrace) => _ErrorState(
                              message: 'Could not load your settings.',
                              onRetry: () {
                                ref.invalidate(settingsProvider(uid));
                              },
                            ),
                            data: (settings) {
                              final expenseCategories =
                                  categories
                                      .where(
                                        (category) =>
                                            category.isExpense &&
                                            !category.archived,
                                      )
                                      .toList()
                                    ..sort(
                                      (a, b) => a.name.toLowerCase().compareTo(
                                        b.name.toLowerCase(),
                                      ),
                                    );

                              final budgetByCategory = <String, Budget>{
                                for (final budget in budgets)
                                  budget.categoryId: budget,
                              };

                              final preferredCurrency = _validCurrency(
                                settings?.displayMode,
                                'CDF',
                              );

                              final monthStart = DateTime(
                                selectedMonth.year,
                                selectedMonth.month,
                              );

                              final monthEnd = DateTime(
                                selectedMonth.year,
                                selectedMonth.month + 1,
                              );

                              final summaries = expenseCategories.map((
                                category,
                              ) {
                                final budget = budgetByCategory[category.id];

                                final currency = _validCurrency(
                                  budget?.currency,
                                  preferredCurrency,
                                );

                                final spent = transactions
                                    .where(
                                      (transaction) =>
                                          transaction.type == 'expense' &&
                                          transaction.categoryId ==
                                              category.id &&
                                          transaction.currency == currency &&
                                          !transaction.date.isBefore(
                                            monthStart,
                                          ) &&
                                          transaction.date.isBefore(monthEnd),
                                    )
                                    .fold<int>(
                                      0,
                                      (total, transaction) =>
                                          total + transaction.amount,
                                    );

                                return _BudgetSummary(
                                  category: category,
                                  budget: budget,
                                  currency: currency,
                                  spent: spent,
                                );
                              }).toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _OverviewSection(
                                    summaries: summaries,
                                    currency: 'CDF',
                                  ),
                                  if (summaries.any(
                                    (item) => item.currency == 'USD',
                                  )) ...[
                                    const SizedBox(height: 12),
                                    _OverviewSection(
                                      summaries: summaries,
                                      currency: 'USD',
                                    ),
                                  ],
                                  const SizedBox(height: 28),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Category budgets',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        '${summaries.where((item) => item.budget != null).length}'
                                        ' of ${summaries.length} set',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (summaries.isEmpty)
                                    const _EmptyState()
                                  else
                                    ...summaries.map(
                                      (summary) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _BudgetCard(
                                          summary: summary,
                                          onEdit: () => _openBudgetDialog(
                                            context,
                                            category: summary.category,
                                            budget: summary.budget,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(authProvider)?.uid;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Plan your spending and stay on track.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: uid == null || uid.isEmpty
              ? null
              : () => _openBudgetDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildMonthBanner(BuildContext context, DateTime month) {
    final theme = Theme.of(context);
    final monthLabel = '${_monthName(month.month)} ${month.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly overview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  monthLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _validCurrency(String? preferred, String? fallback) {
    if (preferred != null && (preferred == 'CDF' || preferred == 'USD')) {
      return preferred;
    }

    if (fallback != null && (fallback == 'CDF' || fallback == 'USD')) {
      return fallback;
    }

    return 'CDF';
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  static Future<void> _openBudgetDialog(
    BuildContext context, {
    dynamic category,
    Budget? budget,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BudgetDialog(budget: budget, category: category),
    );
  }
}

class _BudgetSummary {
  const _BudgetSummary({
    required this.category,
    required this.budget,
    required this.currency,
    required this.spent,
  });

  final dynamic category;
  final Budget? budget;
  final String currency;
  final int spent;

  int get limit => budget?.monthlyLimit ?? 0;

  double get progress {
    if (limit <= 0) return 0;
    return (spent / limit).clamp(0.0, 1.0);
  }

  int get percentage {
    if (limit <= 0) return 0;
    return ((spent / limit) * 100).round();
  }

  bool get isOverBudget => limit > 0 && spent > limit;

  int get remaining => limit > spent ? limit - spent : 0;
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.summaries, required this.currency});

  final List<_BudgetSummary> summaries;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySummaries = summaries
        .where((item) => item.currency == currency)
        .toList();

    if (currencySummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalLimit = currencySummaries.fold<int>(
      0,
      (total, item) => total + item.limit,
    );

    final totalSpent = currencySummaries.fold<int>(
      0,
      (total, item) => total + item.spent,
    );

    final budgetedCount = currencySummaries
        .where((item) => item.budget != null)
        .length;

    final overBudgetCount = currencySummaries
        .where((item) => item.isOverBudget)
        .length;

    final progress = totalLimit > 0
        ? (totalSpent / totalLimit).clamp(0.0, 1.0)
        : 0.0;

    final color = overBudgetCount > 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$currency overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$budgetedCount budget${budgetedCount == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Total spent',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          AmountText(
            amount: totalSpent,
            currency: currency,
            type: 'expense',
            fontSize: 30,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: 'Total budget',
                  amount: totalLimit,
                  currency: currency,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewMetric(
                  label: 'Remaining',
                  amount: totalLimit > totalSpent ? totalLimit - totalSpent : 0,
                  currency: currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalLimit <= 0
                      ? 'No budget limits set'
                      : totalSpent > totalLimit
                      ? 'You are over budget'
                      : 'Budget usage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (totalLimit > 0)
                Text(
                  '${((totalSpent / totalLimit) * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ],
          ),
          if (overBudgetCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$overBudgetCount categor${overBudgetCount == 1 ? 'y is' : 'ies are'} over budget.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final int amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        AmountText(amount: amount, currency: currency, fontSize: 17),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary, required this.onEdit});

  final _BudgetSummary summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfigured = summary.budget != null;

    final statusColor = summary.isOverBudget
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final statusText = !isConfigured
        ? 'Not set'
        : summary.limit <= 0
        ? 'No limit'
        : summary.isOverBudget
        ? 'Over budget'
        : '${summary.percentage}% used';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.category.name as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isConfigured ? 'Edit budget' : 'Set budget',
                onPressed: onEdit,
                icon: Icon(
                  isConfigured
                      ? Icons.edit_outlined
                      : Icons.add_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      amount: summary.spent,
                      currency: summary.currency,
                      type: 'expense',
                      fontSize: 18,
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
                      'Budget limit',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isConfigured)
                      AmountText(
                        amount: summary.limit,
                        currency: summary.currency,
                        fontSize: 18,
                      )
                    else
                      Text(
                        'Not set',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (isConfigured && summary.limit > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.progress,
                minHeight: 7,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.isOverBudget ? 'Exceeded by' : 'Remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                AmountText(
                  amount: summary.isOverBudget
                      ? summary.spent - summary.limit
                      : summary.remaining,
                  currency: summary.currency,
                  type: summary.isOverBudget ? 'expense' : 'income',
                  fontSize: 13,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your budgets…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 46,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No expense categories yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an expense category first, then set a monthly budget for it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

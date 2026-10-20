import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';
import 'package:money_manager/features/budgets/presentation/budget_dialog.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

/// Budgets screen: one budget per expense category with progress bars.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final selectedMonth = ref.watch(selectedMonthProvider);
    final budgetsAsync = ref.watch(budgetProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    return AppShell(
      currentRoute: AppRoutes.budgets,
      child: ResponsiveBody(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Budgets',
                subtitle: 'Set monthly spending limits per category.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Expanded: PrimaryButton is width-infinity, which a Row
                  // only accepts with bounded (flex) constraints.
                  Expanded(
                    child: SecondaryButton(
                      text: 'Add budget',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const BudgetDialog(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(text: 'Save all', onPressed: () {}),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              budgetsAsync.when(
                data: (budgets) => categoriesAsync.when(
                  data: (categories) => transactionsAsync.when(
                    data: (transactions) => settingsAsync.when(
                      data: (setting) {
                        final expenseCategories = categories
                            .where((c) => c.isExpense && !c.archived)
                            .toList();

                        if (expenseCategories.isEmpty) {
                          return const EmptyState(
                            icon: Icons.account_balance_wallet,
                            title: 'No expense categories',
                            subtitle:
                                'Add expense categories in Settings first.',
                          );
                        }

                        final monthStart = DateTime(
                          selectedMonth.year,
                          selectedMonth.month,
                          1,
                        );
                        final monthEnd = DateTime(
                          selectedMonth.year,
                          selectedMonth.month + 1,
                          1,
                        );
                        final displayMode = setting?.displayMode ?? 'CDF';

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: expenseCategories.length,
                          itemBuilder: (_, index) {
                            final cat = expenseCategories[index];
                            final budget = budgets.firstWhere(
                              (b) => b.categoryId == cat.id,
                              orElse: () => Budget(
                                categoryId: cat.id,
                                currency: displayMode,
                                monthlyLimit: 0,
                              ),
                            );
                            final budgetCurrency = budget.currency;
                            final spent = transactions
                                .where(
                                  (t) =>
                                      t.type == 'expense' &&
                                      t.categoryId == cat.id &&
                                      t.currency == budgetCurrency &&
                                      t.date.isAfter(monthStart) &&
                                      t.date.isBefore(monthEnd),
                                )
                                .fold<int>(0, (sum, t) => sum + t.amount);

                            final limit = budget.monthlyLimit;
                            final pct = limit > 0 ? (spent * 100) ~/ limit : 0;

                            return AppCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cat.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '$pct%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: pct >= 100
                                              ? Colors.red
                                              : pct >= 80
                                              ? Colors.orange
                                              : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: limit > 0
                                        ? (spent / limit).clamp(0.0, 1.0)
                                        : 0,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    color: pct >= 100
                                        ? Colors.red
                                        : pct >= 80
                                        ? Colors.orange
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      AmountText(
                                        amount: spent,
                                        currency: budgetCurrency,
                                        fontSize: 14,
                                      ),
                                      const Text(
                                        ' / ',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      AmountText(
                                        amount: limit,
                                        currency: budgetCurrency,
                                        fontSize: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SecondaryButton(
                                    text: 'Edit',
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => BudgetDialog(
                                        budget: budget,
                                        category: cat,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const _LoadingState(),
                      error: (error, stack) => ErrorBanner(
                        message: 'Could not load settings.',
                        fix: 'Check your connection and try again.',
                        onRetry: () => ref.refresh(settingsProvider(uid)),
                      ),
                    ),
                    loading: () => const _LoadingState(),
                    error: (error, stack) => ErrorBanner(
                      message: 'Could not load transactions.',
                      fix: 'Check your connection and try again.',
                      onRetry: () => ref.refresh(transactionProvider(uid)),
                    ),
                  ),
                  loading: () => const _LoadingState(),
                  error: (error, stack) => ErrorBanner(
                    message: 'Could not load categories.',
                    fix: 'Check your connection and try again.',
                    onRetry: () => ref.refresh(categoryProvider(uid)),
                  ),
                ),
                loading: () => const _LoadingState(),
                error: (error, stack) => ErrorBanner(
                  message: 'Could not load budgets.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(budgetProvider(uid)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed-height loading state: safe inside scroll views (no [Expanded]).
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

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/home/application/home_totals.dart';
import 'package:money_manager/features/home/presentation/widgets/combined_total_card.dart';
import 'package:money_manager/features/home/presentation/widgets/display_mode_toggle.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';
import 'package:money_manager/features/transactions/presentation/transaction_delete_undo.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';

/// Home screen: wallet balances, month summary, recent transactions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final selectedMonth = ref.watch(selectedMonthProvider);
    final walletsAsync = ref.watch(walletProvider(uid));
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final budgetsAsync = ref.watch(budgetProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;

    return ResponsiveBody(
      maxWidth: width >= 900 ? 1040 : null,
      padding: EdgeInsets.only(
        left: isPhone ? 16 : 24,
        top: 0,
        right: isPhone ? 16 : 24,
        bottom: isPhone ? 16 : 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Home',
                subtitle: 'Your money at a glance.',
              ),
              const SizedBox(height: 8),
              _buildMonthNavigation(ref, context, selectedMonth),
              const SizedBox(height: 8),
              walletsAsync.when(
                data: (wallets) => transactionsAsync.when(
                  data: (transactions) => budgetsAsync.when(
                    data: (budgets) => categoriesAsync.when(
                      data: (categories) => settingsAsync.when(
                        data: (setting) {
                          final filtered = transactions
                              .where((t) => _inMonth(t.date, selectedMonth))
                              .toList();

                          return _buildForWidth(
                            context,
                            ref,
                            uid,
                            setting,
                            wallets,
                            filtered,
                            budgets,
                            categories,
                            selectedMonth,
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
                  loading: () => const _LoadingState(),
                  error: (error, stack) => ErrorBanner(
                    message: 'Could not load transactions.',
                    fix: 'Check your connection and try again.',
                    onRetry: () => ref.refresh(transactionProvider(uid)),
                  ),
                ),
                loading: () => const _LoadingState(),
                error: (error, stack) => ErrorBanner(
                  message: 'Could not load your wallets.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(walletProvider(uid)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// True when [date] falls inside the month of [month] (start inclusive).
  static bool _inMonth(DateTime date, DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    return !date.isBefore(monthStart) && date.isBefore(monthEnd);
  }

  /// Single-column layout on phones, two columns on wide screens.
  Widget _buildForWidth(
    BuildContext context,
    WidgetRef ref,
    String uid,
    Setting? setting,
    List<Wallet> wallets,
    List<Transaction> transactions,
    List<dynamic> budgets,
    List<Category> categories,
    DateTime selectedMonth,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final displayMode = setting?.displayMode ?? 'combined';

    final balances = _buildBalancesSection(uid, setting, wallets, displayMode);
    final summary = _buildMonthSummary(transactions, displayMode);
    final alerts = _buildBudgetAlerts(
      budgets,
      transactions,
      categories,
      selectedMonth,
    );
    final recent = _buildRecentTransactions(
      context,
      ref,
      transactions,
      categories,
      uid,
    );

    if (width >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                balances,
                const SizedBox(height: 16),
                summary,
                const SizedBox(height: 16),
                alerts,
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: recent),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        balances,
        const SizedBox(height: 16),
        summary,
        const SizedBox(height: 16),
        alerts,
        const SizedBox(height: 16),
        recent,
      ],
    );
  }

  Widget _buildMonthNavigation(
    WidgetRef ref,
    BuildContext context,
    DateTime selectedMonth,
  ) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).previousMonth();
          },
        ),
        Expanded(
          child: DropdownButton<int>(
            value: selectedMonth.year,
            isExpanded: true,
            items: List.generate(10, (i) {
              final year = DateTime.now().year - 2 + i;
              return DropdownMenuItem(value: year, child: Text('$year'));
            }),
            onChanged: (year) {
              if (year != null) {
                ref
                    .read(selectedMonthProvider.notifier)
                    .setMonth(year, selectedMonth.month);
              }
            },
          ),
        ),
        DropdownButton<int>(
          value: selectedMonth.month,
          items: List.generate(12, (i) {
            return DropdownMenuItem(value: i + 1, child: Text(monthNames[i]));
          }),
          onChanged: (month) {
            if (month != null) {
              ref
                  .read(selectedMonthProvider.notifier)
                  .setMonth(selectedMonth.year, month);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).nextMonth();
          },
        ),
      ],
    );
  }

  /// Display toggle, combined total and wallet cards.
  /// The toggle and total need the settings document; without it
  /// (not onboarded yet) only the wallet cards are shown.
  Widget _buildBalancesSection(
    String uid,
    Setting? setting,
    List<Wallet> wallets,
    String displayMode,
  ) {
    final cdfWallet = wallets.firstWhereOrNull((w) => w.currency == 'CDF');
    final usdWallet = wallets.firstWhereOrNull((w) => w.currency == 'USD');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setting != null) ...[
          DisplayModeToggle(uid: uid, setting: setting),
          const SizedBox(height: 12),
          CombinedTotalCard(
            cdfWallet: cdfWallet,
            usdWallet: usdWallet,
            rateScaled: setting.usdToCdfRate,
            displayMode: displayMode,
          ),
          const SizedBox(height: 12),
        ],
        _buildWalletBalances(cdfWallet, usdWallet, displayMode),
      ],
    );
  }

  Widget _buildWalletBalances(
    Wallet? cdfWallet,
    Wallet? usdWallet,
    String displayMode,
  ) {
    final showCdf = displayMode != 'usd';
    final showUsd = displayMode != 'cdf';

    return Row(
      children: [
        if (showCdf)
          Expanded(child: _walletCard('CDF', cdfWallet?.balance ?? 0)),
        if (showCdf && showUsd) const SizedBox(width: 12),
        if (showUsd)
          Expanded(child: _walletCard('USD', usdWallet?.balance ?? 0)),
      ],
    );
  }

  Widget _walletCard(String currency, int balance) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          AmountText(
            amount: balance,
            currency: currency,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }

  /// Month income/expense/net in the display currency, converting each
  /// transaction with its own rateAtEntry.
  Widget _buildMonthSummary(
    List<Transaction> transactions,
    String displayMode,
  ) {
    final summary = monthSummary(
      transactions: transactions,
      target: targetCurrencyFor(displayMode),
    );

    return Row(
      children: [
        Expanded(
          child: _statTile(
            'Income',
            summary.income,
            summary.currency,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Expense',
            summary.expense,
            summary.currency,
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile('Net', summary.net, summary.currency, Colors.blue),
        ),
      ],
    );
  }

  Widget _statTile(String title, int amount, String currency, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          AmountText(
            amount: amount,
            currency: currency,
            showSign: title == 'Net',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAlerts(
    List<dynamic> budgets,
    List<Transaction> transactions,
    List<Category> categories,
    DateTime selectedMonth,
  ) {
    final alerts = <String>[];

    for (final budget in budgets) {
      final matching = categories.where(
        (category) => category.id == budget.categoryId,
      );

      if (matching.isEmpty) continue;

      final category = matching.first;

      final spent = transactions
          .where(
            (transaction) =>
                transaction.type == 'expense' &&
                transaction.categoryId == budget.categoryId &&
                transaction.currency == budget.currency &&
                _inMonth(transaction.date, selectedMonth),
          )
          .fold<int>(0, (sum, transaction) => sum + transaction.amount);

      final percentage = budget.monthlyLimit > 0
          ? (spent * 100) ~/ budget.monthlyLimit
          : 0;

      if (percentage >= 100) {
        alerts.add('${category.name} budget exceeded ($percentage%)');
      } else if (percentage >= 80) {
        alerts.add('${category.name} budget warning ($percentage%)');
      }
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Budget alerts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(alert)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    List<Transaction> transactions,
    List<Category> categories,
    String uid,
  ) {
    final recent = transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'Recent transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.transactions),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long,
            title: 'No recent transactions',
            subtitle: 'Add your first transaction to see it here.',
          )
        else
          ...recent.map((transaction) {
            final matching = categories.where(
              (category) => category.id == transaction.categoryId,
            );

            if (matching.isEmpty) return const SizedBox.shrink();

            return TransactionListItem(
              transaction: transaction,
              category: matching.first,
              onTap: () =>
                  _openTransactionSheet(context, transaction: transaction),
              onDelete: () => deleteTransactionWithUndo(
                context: context,
                ref: ref,
                uid: uid,
                transaction: transaction,
                categoryName: matching.first.name,
              ),
            );
          }),
      ],
    );
  }
}

Future<void> _openTransactionSheet(
  BuildContext context, {
  Transaction? transaction,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddEditTransactionSheet(transaction: transaction),
  );
}

/// Fixed-height loading state: safe inside scroll views.
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

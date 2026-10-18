import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';

/// Home screen: wallet balances, month summary, recent transactions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _displayMode = 'combined'; // cdf | usd | combined
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final uid = 'current_user'; // TODO: replace with actual uid from auth
    final walletsAsync = ref.watch(walletProvider(uid));
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final budgetsAsync = ref.watch(budgetProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    return AppShell(
      currentRoute: AppRoutes.home,
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Home',
              subtitle: 'Your money at a glance.',
            ),
            const SizedBox(height: 16),
            // Display toggle
            _buildDisplayToggle(),
            const SizedBox(height: 16),
            // Combined async data
            walletsAsync.when(
              data: (wallets) => transactionsAsync.when(
                data: (transactions) => budgetsAsync.when(
                  data: (budgets) => categoriesAsync.when(
                    data: (categories) => settingsAsync.when(
                      data: (setting) {
                        if (setting != null) {
                          _displayMode = setting.displayMode;
                        }
                        final filtered = _filterByMonth(transactions);
                        return Column(
                          children: [
                            // Wallet balances
                            _buildWalletBalances(wallets, setting),
                            const SizedBox(height: 24),
                            // Month summary
                            _buildMonthSummary(filtered, setting),
                            const SizedBox(height: 24),
                            // Budget alerts
                            _buildBudgetAlerts(budgets, filtered, categories),
                            const SizedBox(height: 24),
                            // Recent transactions
                            _buildRecentTransactions(
                              filtered,
                              categories,
                              wallets,
                            ),
                          ],
                        );
                      },
                      loading: () => const _LoadingRow(),
                      error: (_, __) => const _ErrorRow(),
                    ),
                    loading: () => const _LoadingRow(),
                    error: (_, __) => const _ErrorRow(),
                  ),
                  loading: () => const _LoadingRow(),
                  error: (_, __) => const _ErrorRow(),
                ),
                loading: () => const _LoadingRow(),
                error: (_, __) => const _ErrorRow(),
              ),
              loading: () => const _LoadingRow(),
              error: (_, __) => const _ErrorRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayToggle() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'cdf',
          label: Text('CDF'),
          icon: Icon(Icons.attach_money),
        ),
        ButtonSegment(
          value: 'usd',
          label: Text('USD'),
          icon: Icon(Icons.monetization_on),
        ),
        ButtonSegment(
          value: 'combined',
          label: Text('Both'),
          icon: Icon(Icons.account_balance_wallet),
        ),
      ],
      selected: {_displayMode},
      onSelectionChanged: (selection) {
        setState(() => _displayMode = selection.first);
      },
    );
  }

  Widget _buildWalletBalances(List<dynamic> wallets, dynamic setting) {
    final cdfWallet = wallets.where((w) => w.currency == 'CDF').firstOrNull;
    final usdWallet = wallets.where((w) => w.currency == 'USD').firstOrNull;

    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CDF',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                AmountText(
                  amount: cdfWallet?.balance ?? 0,
                  currency: 'CDF',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'USD',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                AmountText(
                  amount: usdWallet?.balance ?? 0,
                  currency: 'USD',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSummary(List<Transaction> transactions, dynamic setting) {
    final income = transactions
        .where((t) => t.type == 'income')
        .fold<int>(0, (sum, t) => sum + t.amount);
    final expense = transactions
        .where((t) => t.type == 'expense')
        .fold<int>(0, (sum, t) => sum + t.amount);
    final net = income - expense;

    return Row(
      children: [
        Expanded(child: _statTile('Income', income, 'CDF', Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _statTile('Expense', expense, 'CDF', Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _statTile('Net', net, 'CDF', Colors.blue)),
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
          const SizedBox(height: 4),
          AmountText(
            amount: amount,
            currency: currency,
            showSign: title == 'Net',
            fontSize: 20,
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
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final alerts = <String>[];
    for (final budget in budgets) {
      final cat = categories.firstWhere(
        (c) => c.id == budget.categoryId,
        orElse: () => categories.first,
      );
      final spent = transactions
          .where(
            (t) =>
                t.type == 'expense' &&
                t.categoryId == budget.categoryId &&
                t.currency == budget.currency &&
                t.date.isAfter(monthStart) &&
                t.date.isBefore(monthEnd),
          )
          .fold<int>(0, (sum, t) => sum + t.amount);

      final pct = budget.monthlyLimit > 0
          ? (spent * 100) ~/ budget.monthlyLimit
          : 0;

      if (pct >= 100) {
        alerts.add('${cat.name} budget exceeded ($pct%)');
      } else if (pct >= 80) {
        alerts.add('${cat.name} budget warning ($pct%)');
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
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    List<Transaction> transactions,
    List<Category> categories,
    List<dynamic> wallets,
  ) {
    final recent = transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
          ...recent.map((txn) {
            final cat = categories.firstWhere(
              (c) => c.id == txn.categoryId,
              orElse: () => categories.first,
            );
            return TransactionListItem(
              transaction: txn,
              category: cat,
              onTap: () {},
              onDelete: () {},
            );
          }),
      ],
    );
  }

  List<Transaction> _filterByMonth(List<Transaction> transactions) {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    return transactions.where((t) {
      return t.date.isAfter(monthStart) && t.date.isBefore(monthEnd);
    }).toList();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? firstOrNull(bool Function(T element)? test) {
    if (test == null) {
      return isEmpty ? null : first;
    }
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Expanded(child: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorRow({this.message = 'Failed to load', this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SecondaryButton(text: 'Retry', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

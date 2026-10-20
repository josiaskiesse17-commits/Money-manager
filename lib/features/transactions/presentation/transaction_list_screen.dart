import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';

/// Transactions list with month navigation, search, and filters.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final walletsAsync = ref.watch(walletProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    return ResponsiveBody(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Transactions',
            subtitle: 'View, search, and filter your income and expenses.',
          ),
          const SizedBox(height: 16),
          _buildMonthNavigation(ref, context, selectedMonth),
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) => categoriesAsync.when(
                data: (categories) => walletsAsync.when(
                  data: (wallets) => settingsAsync.when(
                    data: (setting) {
                      final filtered = _filter(
                        transactions,
                        categories,
                        wallets,
                        setting,
                        selectedMonth,
                      );
                      return _buildList(
                        ref,
                        context,
                        filtered,
                        categories,
                        wallets,
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
                  message: 'Could not load wallets.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(walletProvider(uid)),
                ),
              ),
              loading: () => const _LoadingState(),
              error: (error, stack) => ErrorBanner(
                message: 'Could not load transactions.',
                fix: 'Check your connection and try again.',
                onRetry: () => ref.refresh(transactionProvider(uid)),
              ),
            ),
          ),
        ],
      ),
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
              final y = DateTime.now().year - 2 + i;
              return DropdownMenuItem(value: y, child: Text('$y'));
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

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: TextEditingController(),
            label: 'Search note',
            helperText: 'Search transaction notes',
            onChanged: (v) {},
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: SecondaryButton(
            text: 'Filters',
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Filters'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                      FilterChip(
                        label: const Text('CDF'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                      FilterChip(
                        label: const Text('USD'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'Cancel',
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: 'Apply',
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Transaction> _filter(
    List<Transaction> transactions,
    List<Category> categories,
    List<dynamic> wallets,
    dynamic setting,
    DateTime selectedMonth,
  ) {
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    return transactions.where((txn) {
      if (txn.date.isBefore(monthStart) || txn.date.isAfter(monthEnd)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Widget _buildList(
    WidgetRef ref,
    BuildContext context,
    List<Transaction> transactions,
    List<Category> categories,
    List<dynamic> wallets,
  ) {
    if (transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long,
        title: 'No transactions yet',
        subtitle: 'Add your first income or expense to get started.',
        action: SecondaryButton(
          text: 'Add transaction',
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddEditTransactionSheet(),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (_, index) {
        final txn = transactions[index];
        final cat = categories.where((c) => c.id == txn.categoryId).firstOrNull;
        if (cat == null) return const SizedBox.shrink();
        return TransactionListItem(
          transaction: txn,
          category: cat,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddEditTransactionSheet(transaction: txn),
          ),
          onDelete: () => _deleteTransaction(ref, context, txn),
        );
      },
    );
  }

  void _deleteTransaction(
    WidgetRef ref,
    BuildContext context,
    Transaction txn,
  ) {
    final user = ref.read(authProvider);
    final uid = user?.uid ?? '';
    ref.read(transactionProvider(uid).notifier).delete(txn);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Transaction deleted')));
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';
import 'package:money_manager/features/wallets/application/wallet_provider.dart';

/// Transactions list with month navigation, search, and filters.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _selectedCategoryId;
  String? _selectedWallet;
  String _search = '';
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final uid = 'current_user'; // TODO: replace with actual uid from auth
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));
    final walletsAsync = ref.watch(walletProvider(uid));
    final settingsAsync = ref.watch(settingsProvider(uid));

    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Transactions',
            subtitle: 'View, search, and filter your income and expenses.',
          ),
          const SizedBox(height: 16),
          _buildMonthBar(context),
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          transactionsAsync.when(
            data: (transactions) => categoriesAsync.when(
              data: (categories) => walletsAsync.when(
                data: (wallets) => settingsAsync.when(
                  data: (setting) {
                    final filtered = _filter(
                      transactions,
                      categories,
                      wallets,
                      setting,
                    );
                    return _buildList(context, filtered, categories, wallets);
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
            error: (error, stack) => _ErrorRow(
              message: 'Failed to load transactions',
              onRetry: () => ref.refresh(transactionProvider(uid)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBar(BuildContext context) {
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
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 12,
        itemBuilder: (_, index) {
          final isSelected =
              index == _selectedMonth.month - 1 &&
              _selectedMonth.year == DateTime.now().year;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(monthNames[index]),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedMonth = DateTime(DateTime.now().year, index + 1, 1);
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: TextEditingController(text: _search),
            label: 'Search note',
            helperText: 'Search transaction notes',
            onChanged: (v) => setState(() => _search = v),
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
                        selected: _selectedCategoryId == null,
                        onSelected: (_) =>
                            setSheetState(() => _selectedCategoryId = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedWallet == null,
                        onSelected: (_) =>
                            setSheetState(() => _selectedWallet = null),
                      ),
                      FilterChip(
                        label: const Text('CDF'),
                        selected: _selectedWallet == 'CDF',
                        onSelected: (_) =>
                            setSheetState(() => _selectedWallet = 'CDF'),
                      ),
                      FilterChip(
                        label: const Text('USD'),
                        selected: _selectedWallet == 'USD',
                        onSelected: (_) =>
                            setSheetState(() => _selectedWallet = 'USD'),
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
  ) {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    return transactions.where((txn) {
      if (txn.date.isBefore(monthStart) || txn.date.isAfter(monthEnd)) {
        return false;
      }
      if (_selectedCategoryId != null &&
          txn.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedWallet != null && txn.currency != _selectedWallet) {
        return false;
      }
      if (_search.isNotEmpty &&
          (txn.note ?? '').toLowerCase().contains(_search.toLowerCase()) ==
              false) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Widget _buildList(
    BuildContext context,
    List<Transaction> transactions,
    List<Category> categories,
    List<dynamic> wallets,
  ) {
    if (transactions.isEmpty) {
      return Expanded(
        child: EmptyState(
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
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (_, index) {
          final txn = transactions[index];
          final cat = categories.firstWhere(
            (c) => c.id == txn.categoryId,
            orElse: () => categories.first,
          );
          return TransactionListItem(
            transaction: txn,
            category: cat,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => AddEditTransactionSheet(transaction: txn),
            ),
            onDelete: () => _deleteTransaction(context, txn),
          );
        },
      ),
    );
  }

  void _deleteTransaction(BuildContext context, Transaction txn) {
    ref.read(transactionProvider('current_user').notifier).delete(txn);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Transaction deleted')));
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

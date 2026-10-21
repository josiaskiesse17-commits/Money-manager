import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _typeFilter = 'all';
  String _currencyFilter = 'all';

  bool get _hasActiveFilters =>
      _typeFilter != 'all' || _currencyFilter != 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));

    return Scaffold(
      body: ResponsiveBody(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Transactions',
                subtitle: 'Track your income and expenses, all in one place.',
              ),
              const SizedBox(height: 24),
              _buildMonthNavigation(selectedMonth),
              const SizedBox(height: 20),
              _buildSearchAndFilters(),
              const SizedBox(height: 16),
              Expanded(
                child: transactionsAsync.when(
                  loading: () => const _LoadingState(),
                  error: (error, stackTrace) => ErrorBanner(
                    message: 'Could not load transactions.',
                    fix: 'Check your connection and try again.',
                    onRetry: () {
                      ref.invalidate(transactionProvider(uid));
                    },
                  ),
                  data: (transactions) {
                    return categoriesAsync.when(
                      loading: () => const _LoadingState(),
                      error: (error, stackTrace) => ErrorBanner(
                        message: 'Could not load categories.',
                        fix: 'Check your connection and try again.',
                        onRetry: () {
                          ref.invalidate(categoryProvider(uid));
                        },
                      ),
                      data: (categories) {
                        final filteredTransactions = _filterTransactions(
                          transactions: transactions,
                          categories: categories,
                          selectedMonth: selectedMonth,
                        );

                        return _buildTransactionList(
                          transactions: filteredTransactions,
                          allTransactions: transactions,
                          categories: categories,
                          uid: uid,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigation(DateTime selectedMonth) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final firstYear = selectedMonth.year < now.year - 10
        ? selectedMonth.year
        : now.year - 10;

    final lastYear = selectedMonth.year > now.year + 2
        ? selectedMonth.year
        : now.year + 2;

    final years = List.generate(
      lastYear - firstYear + 1,
      (index) => firstYear + index,
    );

    const monthNames = [
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

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporting period',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${monthNames[selectedMonth.month - 1]} '
                        '${selectedMonth.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).previousMonth();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).nextMonth();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;

                final monthField = DropdownButtonFormField<int>(
                  initialValue: selectedMonth.month,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    prefixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text(
                        monthNames[index],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  onChanged: (month) {
                    if (month == null) return;

                    ref
                        .read(selectedMonthProvider.notifier)
                        .setMonth(selectedMonth.year, month);
                  },
                );

                final yearField = DropdownButtonFormField<int>(
                  initialValue: selectedMonth.year,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    prefixIcon: const Icon(Icons.event_outlined, size: 18),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: years
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text('$year'),
                        ),
                      )
                      .toList(),
                  onChanged: (year) {
                    if (year == null) return;

                    ref
                        .read(selectedMonthProvider.notifier)
                        .setMonth(year, selectedMonth.month);
                  },
                );

                if (compact) {
                  return Column(
                    children: [
                      monthField,
                      const SizedBox(height: 12),
                      yearField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: monthField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: yearField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;

        final searchField = AppTextField(
          controller: _searchController,
          label: 'Search transactions',
          helperText: 'Search notes, categories, type or currency',
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim();
            });
          },
        );

        final filterButton = OutlinedButton.icon(
          onPressed: _showFilterBottomSheet,
          icon: Badge(
            isLabelVisible: _hasActiveFilters,
            child: const Icon(Icons.tune),
          ),
          label: Text(_hasActiveFilters ? 'Filters applied' : 'Filters'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: filterButton),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: filterButton,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFilterBottomSheet() async {
    var draftType = _typeFilter;
    var draftCurrency = _currencyFilter;

    final result = await showModalBottomSheet<_TransactionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter transactions',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Narrow your results by type and currency.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Transaction type',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All types',
                          value: 'all',
                          currentValue: draftType,
                          onSelected: (value) {
                            setSheetState(() => draftType = value);
                          },
                        ),
                        _buildFilterChip(
                          label: 'Income',
                          value: 'income',
                          currentValue: draftType,
                          onSelected: (value) {
                            setSheetState(() => draftType = value);
                          },
                        ),
                        _buildFilterChip(
                          label: 'Expenses',
                          value: 'expense',
                          currentValue: draftType,
                          onSelected: (value) {
                            setSheetState(() => draftType = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Currency', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All currencies',
                          value: 'all',
                          currentValue: draftCurrency,
                          onSelected: (value) {
                            setSheetState(() => draftCurrency = value);
                          },
                        ),
                        _buildFilterChip(
                          label: 'CDF',
                          value: 'CDF',
                          currentValue: draftCurrency,
                          onSelected: (value) {
                            setSheetState(() => draftCurrency = value);
                          },
                        ),
                        _buildFilterChip(
                          label: 'USD',
                          value: 'USD',
                          currentValue: draftCurrency,
                          onSelected: (value) {
                            setSheetState(() => draftCurrency = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                draftType = 'all';
                                draftCurrency = 'all';
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _TransactionFilters(
                                  type: draftType,
                                  currency: draftCurrency,
                                ),
                              );
                            },
                            child: const Text('Apply filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _typeFilter = result.type;
      _currencyFilter = result.currency;
    });
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: currentValue == value,
      onSelected: (_) => onSelected(value),
    );
  }

  List<Transaction> _filterTransactions({
    required List<Transaction> transactions,
    required List<Category> categories,
    required DateTime selectedMonth,
  }) {
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month);

    final nextMonthStart = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
    );

    final categoryById = {
      for (final category in categories) category.id: category,
    };

    final query = _searchQuery.toLowerCase();

    return transactions.where((transaction) {
      if (transaction.date.isBefore(monthStart) ||
          !transaction.date.isBefore(nextMonthStart)) {
        return false;
      }

      if (_typeFilter != 'all' && transaction.type != _typeFilter) {
        return false;
      }

      if (_currencyFilter != 'all' &&
          transaction.currency.toUpperCase() != _currencyFilter) {
        return false;
      }

      if (query.isNotEmpty) {
        final category = categoryById[transaction.categoryId];
        final note = (transaction.note ?? '').toLowerCase();
        final categoryName = category?.name.toLowerCase() ?? '';
        final type = transaction.type.toLowerCase();
        final currency = transaction.currency.toLowerCase();

        final matchesSearch =
            note.contains(query) ||
            categoryName.contains(query) ||
            type.contains(query) ||
            currency.contains(query);

        if (!matchesSearch) return false;
      }

      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Widget _buildTransactionList({
    required List<Transaction> transactions,
    required List<Transaction> allTransactions,
    required List<Category> categories,
    required String uid,
  }) {
    final theme = Theme.of(context);

    if (transactions.isEmpty) {
      final hasAnyTransactions = allTransactions.isNotEmpty;

      return EmptyState(
        icon: hasAnyTransactions
            ? Icons.search_off_outlined
            : Icons.receipt_long_outlined,
        title: hasAnyTransactions
            ? 'No matching transactions'
            : 'No transactions this month',
        subtitle: hasAnyTransactions
            ? 'Try changing your search or filters, or select another month.'
            : 'Add an income or expense to start tracking your money.',
        action: hasAnyTransactions
            ? OutlinedButton.icon(
                onPressed: _clearSearchAndFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear search and filters'),
              )
            : SecondaryButton(
                text: 'Add transaction',
                onPressed: () => _openTransactionSheet(),
              ),
      );
    }

    final categoryById = {
      for (final category in categories) category.id: category,
    };

    final visibleTransactions = transactions
        .where(
          (transaction) => categoryById.containsKey(transaction.categoryId),
        )
        .toList();

    if (visibleTransactions.isEmpty) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'No categorized transactions',
        subtitle: 'Transactions with unavailable categories cannot be shown.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${visibleTransactions.length} '
                  '${visibleTransactions.length == 1 ? 'transaction' : 'transactions'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters || _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearSearchAndFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: visibleTransactions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final transaction = visibleTransactions[index];
              final category = categoryById[transaction.categoryId]!;

              return TransactionListItem(
                transaction: transaction,
                category: category,
                onTap: () => _openTransactionSheet(transaction: transaction),
                onDelete: () => _deleteTransaction(transaction, uid),
              );
            },
          ),
        ),
      ],
    );
  }

  void _clearSearchAndFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _typeFilter = 'all';
      _currencyFilter = 'all';
    });
  }

  Future<void> _openTransactionSheet({Transaction? transaction}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddEditTransactionSheet(transaction: transaction),
    );
  }

  Future<void> _deleteTransaction(Transaction transaction, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete transaction?'),
        content: const Text(
          'This transaction will be permanently deleted. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(transactionProvider(uid).notifier).delete(transaction);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted successfully.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the transaction. Please try again.'),
        ),
      );
    }
  }
}

class _TransactionFilters {
  const _TransactionFilters({required this.type, required this.currency});

  final String type;
  final String currency;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

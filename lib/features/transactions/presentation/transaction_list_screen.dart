import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';
import 'package:money_manager/features/transactions/presentation/add_edit_transaction_sheet.dart';
import 'package:money_manager/features/transactions/presentation/transaction_delete_undo.dart';

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
      return const Center(child: CircularProgressIndicator());
    }

    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(transactionProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final compactSpacing = textScale > 1.5;

    return ResponsiveBody(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track your income and expenses, all in one place.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: compactSpacing ? 12 : 24),
                  _buildMonthNavigation(selectedMonth),
                  SizedBox(height: compactSpacing ? 12 : 20),
                  _buildSearchAndFilters(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: true,
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

  Widget _buildSearchAndFilters(BuildContext ctx) {
    final textScale = MediaQuery.textScalerOf(ctx).scale(1.0);
    final compact = MediaQuery.sizeOf(ctx).width < 480;

    final searchField = AppTextField(
      controller: _searchController,
      label: 'Search transactions',
      helperText: textScale < 1.5
          ? 'Search notes, categories, type or currency'
          : null,
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
        Padding(padding: const EdgeInsets.only(top: 2), child: filterButton),
      ],
    );
  }

  Future<void> _showFilterBottomSheet() async {
    var draftType = _typeFilter;
    var draftCurrency = _currencyFilter;

    final result = await showModalBottomSheet<_TransactionFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colors = theme.colorScheme;
            final media = MediaQuery.of(sheetContext);
            final compact = media.size.width < 400;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 20 : 24,
                        8,
                        compact ? 20 : 24,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter transactions',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Narrow results by type and currency.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.6),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          compact ? 20 : 24,
                          18,
                          compact ? 20 : 24,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TRANSACTION TYPE',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _FilterChoiceGroup(
                              options: const [
                                _FilterOption('All types', 'all'),
                                _FilterOption('Income', 'income'),
                                _FilterOption('Expenses', 'expense'),
                              ],
                              selectedValue: draftType,
                              onSelected: (value) {
                                setSheetState(() {
                                  draftType = value;
                                });
                              },
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'PAYMENT CURRENCY',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _FilterCurrencyOption(
                                      label: 'All',
                                      description: 'Any currency',
                                      symbol: '↔',
                                      selected: draftCurrency == 'all',
                                      onTap: () {
                                        setSheetState(() {
                                          draftCurrency = 'all';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _FilterCurrencyOption(
                                      label: 'CDF',
                                      description: 'Congolese franc',
                                      symbol: 'FC',
                                      selected: draftCurrency == 'CDF',
                                      onTap: () {
                                        setSheetState(() {
                                          draftCurrency = 'CDF';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _FilterCurrencyOption(
                                      label: 'USD',
                                      description: 'US dollar',
                                      symbol: '\$',
                                      selected: draftCurrency == 'USD',
                                      onTap: () {
                                        setSheetState(() {
                                          draftCurrency = 'USD';
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.6),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 20 : 24,
                        12,
                        compact ? 20 : 24,
                        12 + media.padding.bottom,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  draftType = 'all';
                                  draftCurrency = 'all';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
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
    final categoryById = {
      for (final category in ref.read(categoryProvider(uid)).value ?? [])
        category.id: category,
    };
    final category = categoryById[transaction.categoryId];
    await deleteTransactionWithUndo(
      context: context,
      ref: ref,
      uid: uid,
      transaction: transaction,
      categoryName: category?.name ?? 'Unknown',
    );
  }
}

class _TransactionFilters {
  const _TransactionFilters({required this.type, required this.currency});

  final String type;
  final String currency;
}

class _FilterOption {
  const _FilterOption(this.label, this.value);

  final String label;
  final String value;
}

class _FilterChoiceGroup extends StatelessWidget {
  const _FilterChoiceGroup({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<_FilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: options.map((option) {
        final selected = selectedValue == option.value;

        final Color accent = switch (option.value) {
          'expense' => colors.error,
          'income' => colors.primary,
          _ => colors.primary,
        };

        final String symbol = switch (option.value) {
          'expense' => '−',
          'income' => '+',
          _ => '↔',
        };

        final String description = switch (option.value) {
          'expense' => 'Money out',
          'income' => 'Money in',
          _ => 'All types',
        };

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: option.value == 'expense' ? 0 : 8),
            child: Material(
              color: selected ? colors.surface : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: () => onSelected(option.value),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.6)
                          : colors.outlineVariant.withValues(alpha: 0.55),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withValues(alpha: 0.12)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          symbol,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected ? accent : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected ? accent : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FilterCurrencyOption extends StatelessWidget {
  const _FilterCurrencyOption({
    required this.label,
    required this.description,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  symbol,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? colors.primary : null,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

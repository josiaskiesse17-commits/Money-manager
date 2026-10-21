import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

class BudgetDialog extends ConsumerStatefulWidget {
  const BudgetDialog({super.key, this.budget, this.category});

  final Budget? budget;
  final Category? category;

  @override
  ConsumerState<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<BudgetDialog> {
  final _limitController = TextEditingController();

  String? _categoryId;
  String _currency = 'CDF';
  String? _error;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _initializeForm({
    required List<Category> categories,
    required String? preferredCurrency,
  }) {
    if (_initialized) return;

    final expenseCategories = categories
        .where((category) => category.isExpense && !category.archived)
        .toList();

    final requestedCategoryId =
        widget.category?.id ?? widget.budget?.categoryId;

    _categoryId = expenseCategories
        .where((category) => category.id == requestedCategoryId)
        .firstOrNull
        ?.id;

    _categoryId ??= expenseCategories.isEmpty
        ? null
        : expenseCategories.first.id;

    final savedCurrency = widget.budget?.currency;

    if (savedCurrency == 'USD' || savedCurrency == 'CDF') {
      _currency = savedCurrency!;
    } else {
      _currency = preferredCurrency == 'USD' ? 'USD' : 'CDF';
    }

    final existingBudget = widget.budget;
    if (existingBudget != null) {
      _limitController.text = _currency == 'USD'
          ? (existingBudget.monthlyLimit / 100).toStringAsFixed(2)
          : existingBudget.monthlyLimit.toString();
    }

    _initialized = true;
  }

  int? _parseLimit(String input) {
    final value = input.trim().replaceAll(',', '');

    if (value.isEmpty) return null;

    if (_currency == 'USD') {
      final parsed = double.tryParse(value);

      if (parsed == null ||
          !parsed.isFinite ||
          parsed <= 0 ||
          parsed > 999999999) {
        return null;
      }

      return (parsed * 100).round();
    }

    // CDF is stored in whole francs.
    if (value.contains('.')) return null;

    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) return null;

    return parsed;
  }

  Future<void> _save(String uid) async {
    if (_saving) return;

    if (uid.isEmpty) {
      setState(
        () => _error = 'Your session has expired. Please sign in again.',
      );
      return;
    }

    final categories = ref.read(categoryProvider(uid)).valueOrNull ?? [];
    final activeCategory = categories.where(
      (category) =>
          category.id == _categoryId &&
          category.isExpense &&
          !category.archived,
    );

    if (activeCategory.isEmpty) {
      setState(() {
        _error = 'Select an active expense category.';
      });
      return;
    }

    final limit = _parseLimit(_limitController.text);

    if (limit == null) {
      setState(() {
        _error = _currency == 'USD'
            ? 'Enter a valid USD amount greater than zero.'
            : 'Enter a whole-number CDF amount greater than zero.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(budgetProvider(uid).notifier)
          .save(
            Budget(
              categoryId: _categoryId!,
              currency: _currency,
              monthlyLimit: limit,
            ),
          );

      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save the budget. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return AlertDialog(
        title: const Text('Budget'),
        content: const Text('Please sign in to manage budgets.'),
        actions: [
          SecondaryButton(text: 'Close', onPressed: () => context.pop()),
        ],
      );
    }

    return ref
        .watch(categoryProvider(uid))
        .when(
          loading: () => const AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => AlertDialog(
            title: const Text('Unable to load categories'),
            content: const Text(
              'Please try again when your categories are available.',
            ),
            actions: [
              SecondaryButton(text: 'Close', onPressed: () => context.pop()),
            ],
          ),
          data: (categories) =>
              _buildWithSettings(uid: uid, categories: categories),
        );
  }

  Widget _buildWithSettings({
    required String uid,
    required List<Category> categories,
  }) {
    return ref
        .watch(settingsProvider(uid))
        .when(
          loading: () => const AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => AlertDialog(
            title: const Text('Unable to load settings'),
            content: const Text(
              'Your settings could not be loaded. Please try again.',
            ),
            actions: [
              SecondaryButton(text: 'Close', onPressed: () => context.pop()),
            ],
          ),
          data: (settings) {
            _initializeForm(
              categories: categories,
              preferredCurrency: settings?.displayMode,
            );

            final expenseCategories = categories
                .where((category) => category.isExpense && !category.archived)
                .toList();

            if (expenseCategories.isEmpty) {
              return AlertDialog(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('No expense categories'),
                content: const Text(
                  'Create an active expense category before setting a budget.',
                ),
                actions: [
                  SecondaryButton(
                    text: 'Close',
                    onPressed: () => context.pop(),
                  ),
                ],
              );
            }

            if (!expenseCategories.any(
              (category) => category.id == _categoryId,
            )) {
              _categoryId = expenseCategories.first.id;
            }

            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              title: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.budget == null
                          ? Icons.add_chart_rounded
                          : Icons.edit_note_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.budget == null
                              ? 'Create budget'
                              : 'Edit budget',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set a monthly spending limit',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colors.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: colors.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'EXPENSE CATEGORY',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        dropdownColor: colors.surfaceContainerLow,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colors.surfaceContainerLow,
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        items: expenseCategories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _categoryId = value;
                                  _error = null;
                                });
                              },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'MONTHLY LIMIT',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _limitController,
                        label: _currency == 'USD'
                            ? 'Amount in US dollars'
                            : 'Amount in Congolese francs',
                        helperText: _currency == 'USD'
                            ? 'Example: 125.50'
                            : 'Enter a whole number, e.g. 250000',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !_saving,
                        onChanged: (_) {
                          if (_error != null) {
                            setState(() => _error = null);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'BUDGET CURRENCY',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _CurrencyOption(
                                label: 'CDF',
                                subtitle: 'Congolese franc',
                                selected: _currency == 'CDF',
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                          _currency = 'CDF';
                                          _error = null;
                                        }),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: _CurrencyOption(
                                label: 'USD',
                                subtitle: 'US dollar',
                                selected: _currency == 'USD',
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                          _currency = 'USD';
                                          _error = null;
                                        }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                SecondaryButton(
                  text: 'Cancel',
                  onPressed: _saving ? null : () => context.pop(),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  text: widget.budget == null
                      ? 'Create budget'
                      : 'Save changes',
                  busy: _saving,
                  onPressed: _saving ? null : () => _save(uid),
                ),
              ],
            );
          },
        );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    label == 'CDF' ? 'FC' : '\$',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? colors.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
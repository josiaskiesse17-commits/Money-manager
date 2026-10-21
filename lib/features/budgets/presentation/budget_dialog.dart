import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Dialog for adding or editing a budget.
class BudgetDialog extends ConsumerWidget {
  final Budget? budget;
  final Category? category;

  const BudgetDialog({super.key, this.budget, this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';
    final initialCategory = category;
    final initialBudget = budget;

    return ref
        .watch(categoryProvider(uid))
        .when(
          data: (categories) => ref
              .watch(settingsProvider(uid))
              .when(
                data: (setting) {
                  final expenseCategories = categories
                      .where((c) => c.isExpense && !c.archived)
                      .toList();

                  final selectedCategory =
                      initialCategory ??
                      expenseCategories.firstWhere(
                        (c) => c.id == initialBudget?.categoryId,
                        orElse: () => expenseCategories.isNotEmpty
                            ? expenseCategories.first
                            : throw Exception('No expense categories'),
                      );

                  final currency =
                      initialBudget?.currency ?? setting?.displayMode ?? 'CDF';
                  final limitText = initialBudget != null
                      ? (initialBudget.monthlyLimit / 100).toStringAsFixed(2)
                      : '';

                  int? parseLimit(String text, String currency) {
                    final cleaned = text.replaceAll(',', '');
                    if (cleaned.isEmpty) return null;
                    if (currency == 'USD') {
                      final parsed = double.tryParse(cleaned);
                      if (parsed == null || parsed < 0) return null;
                      return (parsed * 100).round();
                    } else {
                      final dotCleaned = cleaned.replaceAll('.', '');
                      final parsed = int.tryParse(dotCleaned);
                      if (parsed == null || parsed < 0) return null;
                      return parsed;
                    }
                  }

                  return StatefulBuilder(
                    builder: (context, setState) {
                      Category categoryValue = selectedCategory;
                      String currencyValue = currency;
                      String limitTextValue = limitText;
                      bool saving = false;
                      String? error;

                      Future<void> saveBudget() async {
                        if (saving) return;
                        final limit = parseLimit(limitTextValue, currencyValue);
                        if (limit == null || limit <= 0) {
                          setState(() {
                            error = 'Enter a valid amount';
                          });
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(budgetProvider(uid).notifier)
                              .save(
                                Budget(
                                  categoryId: categoryValue.id,
                                  currency: currencyValue,
                                  monthlyLimit: limit,
                                ),
                              );
                          if (context.mounted) context.pop();
                        } catch (e) {
                          setState(() {
                            saving = false;
                            error = 'Failed to save budget. Try again.';
                          });
                        }
                      }

                      return AlertDialog(
                        title: Text(
                          initialBudget == null ? 'Add budget' : 'Edit budget',
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error
                                      .withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.error
                                        .withValues(alpha: 0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SectionHeader(title: 'Category'),
                            const SizedBox(height: 8),
                            DropdownButton<Category>(
                              value: categoryValue,
                              isExpanded: true,
                              items: expenseCategories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (c) {
                                if (c != null) {
                                  setState(() {
                                    categoryValue = c;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            const SectionHeader(title: 'Monthly limit'),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: TextEditingController(
                                text: limitTextValue,
                              ),
                              label: 'Limit ($currencyValue)',
                              helperText: currencyValue == 'USD'
                                  ? 'Max 2 decimals'
                                  : 'Whole francs',
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                                  setState(() => limitTextValue = v),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilterChip(
                                    label: const Text('CDF'),
                                    selected: currencyValue == 'CDF',
                                    onSelected: (_) =>
                                        setState(() => currencyValue = 'CDF'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilterChip(
                                    label: const Text('USD'),
                                    selected: currencyValue == 'USD',
                                    onSelected: (_) =>
                                        setState(() => currencyValue = 'USD'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        actions: [
                          SecondaryButton(
                            text: 'Cancel',
                            onPressed: () => context.pop(),
                          ),
                          const SizedBox(width: 8),
                          PrimaryButton(
                            text: 'Save',
                            onPressed: saving ? null : saveBudget,
                            busy: saving,
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, _) => const Text('Failed to load settings'),
              ),
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const Text('Failed to load categories'),
        );
  }
}

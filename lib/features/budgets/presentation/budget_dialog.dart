import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Dialog for adding or editing a budget.
class BudgetDialog extends ConsumerWidget {
  final Budget? budget;
  final Category? category;

  const BudgetDialog({super.key, this.budget, this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = 'current_user';
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

                  return StatefulBuilder(
                    builder: (context, setState) {
                      Category categoryValue = selectedCategory;
                      String currencyValue = currency;
                      String limitTextValue = limitText;

                      return AlertDialog(
                        title: Text(
                          initialBudget == null ? 'Add budget' : 'Edit budget',
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            onPressed: () => context.pop(),
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

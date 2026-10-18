import 'package:flutter/material.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/models/category.dart';

/// Category selection chips for transaction forms.
///
/// Shows one chip per category matching the [selectedType]. Archived
/// categories are hidden unless [includeArchived] is true.
class CategoryChips extends StatelessWidget {
  final List<Category> categories;
  final String selectedType; // 'income' | 'expense'
  final String? selectedId;
  final bool includeArchived;
  final ValueChanged<String> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedType,
    this.selectedId,
    this.includeArchived = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final moneyColors = Theme.of(context).extension<MoneyColors>();
    final filtered = categories.where((c) {
      if (c.type != selectedType) return false;
      if (!includeArchived && c.archived) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filtered.map((c) {
        final isSelected = selectedId == c.id;
        final isExpense = c.type == 'expense';
        final chipColor = isSelected
            ? (isExpense
                  ? (moneyColors?.expense ??
                        Theme.of(context).colorScheme.error)
                  : (moneyColors?.income ??
                        Theme.of(context).colorScheme.primary))
            : null;
        return FilterChip(
          label: Text(c.name),
          selected: isSelected,
          onSelected: (_) => onSelected(c.id),
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          selectedColor: chipColor,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: isSelected
                ? chipColor!
                : Theme.of(context).colorScheme.outline,
          ),
        );
      }).toList(),
    );
  }
}

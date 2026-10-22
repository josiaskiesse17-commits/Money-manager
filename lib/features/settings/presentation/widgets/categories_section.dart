import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/presentation/category_dialog.dart';

/// Categories section: the list of income and expense categories.
class CategoriesSection extends ConsumerStatefulWidget {
  final List<Category> categories;
  final String uid;

  const CategoriesSection({
    super.key,
    required this.categories,
    required this.uid,
  });

  @override
  ConsumerState<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends ConsumerState<CategoriesSection> {
  bool _showArchived = false;

  Future<void> _toggleArchive(Category category) async {
    try {
      await ref
          .read(categoryProvider(widget.uid).notifier)
          .archive(category.id, !category.archived);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            category.archived ? 'Category restored.' : 'Category archived.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the category.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final active = categories.where((category) => !category.archived).toList();
    final archived = categories.where((category) => category.archived).toList();
    final displayed = _showArchived ? categories : active;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Categories',
              subtitle:
                  '${active.length} active'
                  '${archived.isNotEmpty ? ' · ${archived.length} archived' : ''}',
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              EmptyState(
                icon: Icons.category_outlined,
                title: 'No categories yet',
                subtitle:
                    'Add categories to organize your income and expenses.',
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show archived categories'),
                value: _showArchived,
                onChanged: (value) {
                  setState(() {
                    _showArchived = value;
                  });
                },
              ),
              ...displayed.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryRow(
                    category: category,
                    onEdit: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => CategoryDialog(category: category),
                      );
                    },
                    onArchive: () => _toggleArchive(category),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            PrimaryButton(
              text: 'Add category',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const CategoryDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One category with its edit and archive actions.
class _CategoryRow extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.13),
              foregroundColor: color,
              child: Icon(
                category.type == 'income'
                    ? Icons.trending_up
                    : Icons.category_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name.isEmpty ? 'Unnamed category' : category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.type == 'income' ? 'Income' : 'Expense',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (category.archived)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Archived',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final archiveLabel = category.archived ? 'Restore' : 'Archive';

            if (constraints.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SecondaryButton(text: 'Edit', onPressed: onEdit),
                  const SizedBox(height: 8),
                  SecondaryButton(text: archiveLabel, onPressed: onArchive),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: SecondaryButton(text: 'Edit', onPressed: onEdit),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(
                    text: archiveLabel,
                    onPressed: onArchive,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

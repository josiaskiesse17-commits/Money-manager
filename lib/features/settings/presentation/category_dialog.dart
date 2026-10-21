import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';

const _defaultIcons = {'income': 'trending_up', 'expense': 'category'};
const _defaultColors = {'income': 0xFF1B8A4B, 'expense': 0xFFC73E2E};

final List<int> _colorOptions = const [
  0xFF1B8A4B, // green
  0xFFC73E2E, // red
  0xFF2E7D32, // teal green
  0xFFC62828, // dark red
  0xFF1565C0, // blue
  0xFF7B1FA2, // purple
];

/// Dialog for adding or editing a category.
///
/// Edit mode is selected when [category] is non-null; the form is prepopulated
/// and the existing category id is preserved on save.
class CategoryDialog extends ConsumerStatefulWidget {
  final Category? category;

  const CategoryDialog({super.key, this.category});

  @override
  ConsumerState<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<CategoryDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _iconCtrl;
  late String _type;
  late String _icon;
  late int _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _type = cat?.type ?? 'expense';
    _nameCtrl = TextEditingController(text: cat?.name ?? '');
    _iconCtrl = TextEditingController(text: cat?.icon ?? _defaultIcons[_type]!);
    _icon = cat?.icon ?? _defaultIcons[_type]!;
    _color = cat?.color ?? _defaultColors[_type]!;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.category != null;

  Future<void> _saveCategory() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name');
      return;
    }

    final user = ref.read(authProvider);
    final uid = user?.uid ?? '';
    final existing = ref.read(categoryProvider(uid)).valueOrNull ?? const [];

    final duplicate = existing.any((c) {
      if (_isEdit && c.id == widget.category!.id) return false;
      return c.name.toLowerCase() == name.toLowerCase();
    });
    if (duplicate) {
      setState(() => _error = 'A category named "$name" already exists');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final cat = Category(
        id:
            widget.category?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        icon: _icon.trim().isEmpty ? _defaultIcons[_type]! : _icon.trim(),
        color: _color,
        type: _type,
        archived: widget.category?.archived ?? false,
      );
      final router = GoRouter.of(context);
      await ref.read(categoryProvider(uid).notifier).save(cat);
      if (!mounted) return;
      router.pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to save category. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _isEdit;

    return AlertDialog(
      title: Text(isEdit ? 'Edit category' : 'Add category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
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
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SectionHeader(title: 'Name'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _nameCtrl,
              label: 'Category name',
              helperText: 'e.g. Groceries, Salary',
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Income'),
                    selected: _type == 'income',
                    onSelected: (_) => setState(() {
                      _type = 'income';
                      if (_iconCtrl.text.isEmpty) {
                        _icon = _defaultIcons['income']!;
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Expense'),
                    selected: _type == 'expense',
                    onSelected: (_) => setState(() {
                      _type = 'expense';
                      if (_iconCtrl.text.isEmpty) {
                        _icon = _defaultIcons['expense']!;
                      }
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Icon'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _iconCtrl,
              label: 'Icon name',
              helperText: 'Material icon key (e.g. category, trending_up)',
              onChanged: (v) => setState(() {
                _icon = v;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        SecondaryButton(text: 'Cancel', onPressed: () => context.pop()),
        const SizedBox(width: 8),
        PrimaryButton(
          text: 'Save',
          busy: _saving,
          onPressed: _saving ? null : _saveCategory,
        ),
      ],
    );
  }
}

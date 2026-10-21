import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
              isEdit ? Icons.edit_note_rounded : Icons.add_circle_outline,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit category' : 'Add category',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Update your category details'
                      : 'Organize your income and expenses.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            _sectionLabel(context, 'Name'),
            const SizedBox(height: 10),
            AppTextField(
              controller: _nameCtrl,
              label: 'Category name',
              helperText: 'e.g. Groceries, Salary',
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Type'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    title: 'Income',
                    subtitle: 'Money coming in',
                    icon: Icons.trending_up_rounded,
                    selected: _type == 'income',
                    accentColor: colors.primary,
                    onTap: () {
                      if (_type != 'income') {
                        setState(() {
                          _type = 'income';
                          if (_iconCtrl.text.isEmpty) {
                            _icon = _defaultIcons['income']!;
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeCard(
                    title: 'Expense',
                    subtitle: 'Money going out',
                    icon: Icons.category_outlined,
                    selected: _type == 'expense',
                    accentColor: colors.error,
                    onTap: () {
                      if (_type != 'expense') {
                        setState(() {
                          _type = 'expense';
                          if (_iconCtrl.text.isEmpty) {
                            _icon = _defaultIcons['expense']!;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Icon'),
            const SizedBox(height: 10),
            AppTextField(
              controller: _iconCtrl,
              label: 'Icon name',
              helperText: 'Material icon key (e.g. category, trending_up)',
              onChanged: (v) => setState(() {
                _icon = v;
                _error = null;
              }),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Color'),
            const SizedBox(height: 10),
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
                          ? Border.all(color: colors.onSurface, width: 2)
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

  Widget _sectionLabel(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected
          ? accentColor.withValues(alpha: 0.08)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.75)
                  : colors.outlineVariant.withValues(alpha: 0.55),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 21),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? accentColor : colors.outlineVariant,
                    size: 21,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Appearance section: light, dark or system theme.
class AppearanceSection extends ConsumerWidget {
  final Setting setting;
  final String uid;

  const AppearanceSection({
    super.key,
    required this.setting,
    required this.uid,
  });

  static const _supportedThemes = {'light', 'dark', 'system'};

  Future<void> _saveTheme(
    BuildContext context,
    WidgetRef ref,
    String theme,
  ) async {
    try {
      await ref
          .read(settingsProvider(uid).notifier)
          .save(setting.copyWith(theme: theme));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your theme preference.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = _supportedThemes.contains(setting.theme)
        ? setting.theme
        : 'system';

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Choose your preferred app theme.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      _ThemeOption(
                        icon: Icons.light_mode_outlined,
                        label: 'Light',
                        value: 'light',
                        selectedTheme: theme,
                        onSelected: (value) => _saveTheme(context, ref, value),
                      ),
                      const SizedBox(height: 8),
                      _ThemeOption(
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark',
                        value: 'dark',
                        selectedTheme: theme,
                        onSelected: (value) => _saveTheme(context, ref, value),
                      ),
                      const SizedBox(height: 8),
                      _ThemeOption(
                        icon: Icons.settings_suggest_outlined,
                        label: 'System',
                        value: 'system',
                        selectedTheme: theme,
                        onSelected: (value) => _saveTheme(context, ref, value),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<String>(
                        value: 'light',
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment<String>(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                      ButtonSegment<String>(
                        value: 'system',
                        icon: Icon(Icons.settings_suggest_outlined),
                        label: Text('System'),
                      ),
                    ],
                    selected: {theme},
                    onSelectionChanged: (selection) {
                      _saveTheme(context, ref, selection.first);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable theme, used on narrow screens where the segmented button
/// does not fit.
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selectedTheme;
  final ValueChanged<String> onSelected;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selectedTheme,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = selectedTheme == value;

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? colors.onPrimaryContainer : colors.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: colors.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

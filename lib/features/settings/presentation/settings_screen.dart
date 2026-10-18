import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Settings screen: exchange rate, categories, theme, app lock, sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = 'current_user';

    return AppShell(
      currentRoute: AppRoutes.settings,
      child: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Settings',
              subtitle: 'Manage your Money Manager preferences.',
            ),
            const SizedBox(height: 16),
            _SettingsContent(uid: uid),
          ],
        ),
      ),
    );
  }
}

class _SettingsContent extends ConsumerWidget {
  final String uid;

  const _SettingsContent({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(settingsProvider(uid))
        .when(
          data: (setting) => ref
              .watch(categoryProvider(uid))
              .when(
                data: (categories) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExchangeRateCard(setting!),
                    const SizedBox(height: 16),
                    _buildCategoriesSection(categories),
                    const SizedBox(height: 24),
                    _buildThemeCard(setting.theme),
                    const SizedBox(height: 16),
                    _buildAppLockCard(ref),
                    const SizedBox(height: 24),
                    SecondaryButton(
                      text: 'Sign out',
                      onPressed: () => context.go(AppRoutes.signIn),
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, _) => ErrorBanner(message: error.toString()),
              ),
          loading: () => const SizedBox.shrink(),
          error: (error, _) => ErrorBanner(message: error.toString()),
        );
  }

  Widget _buildExchangeRateCard(dynamic setting) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Exchange rate',
            subtitle: 'CDF per 1 USD',
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: TextEditingController(
              text: ((setting as dynamic).usdToCdfRate / 100).toStringAsFixed(
                2,
              ),
            ),
            label: 'Rate (CDF per USD)',
            keyboardType: TextInputType.number,
            onChanged: (v) {},
          ),
          const SizedBox(height: 16),
          PrimaryButton(text: 'Save rate', onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Categories',
          subtitle: 'Add, edit, or archive categories.',
        ),
        const SizedBox(height: 8),
        ...categories.where((c) => !c.archived).map((cat) {
          return AppCard(
            child: ListTile(
              leading: CircleAvatar(child: Text(cat.name[0])),
              title: Text(cat.name),
              subtitle: Text(cat.type == 'income' ? 'Income' : 'Expense'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SecondaryButton(text: 'Edit', onPressed: () {}),
                  const SizedBox(width: 8),
                  SecondaryButton(
                    text: cat.archived ? 'Restore' : 'Archive',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        PrimaryButton(text: 'Add category', onPressed: () {}),
      ],
    );
  }

  Widget _buildThemeCard(String theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Theme',
            subtitle: 'Choose light, dark, or system.',
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('Light')),
              ButtonSegment(value: 'dark', label: Text('Dark')),
              ButtonSegment(value: 'system', label: Text('System')),
            ],
            selected: {theme},
            onSelectionChanged: (selection) {},
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockCard(WidgetRef ref) {
    final hasPin = ref.watch(appLockProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'App lock',
            subtitle: 'Protect your data with a PIN.',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable app lock'),
            value: hasPin,
            onChanged: (v) {},
          ),
          if (hasPin) ...[
            SecondaryButton(text: 'Change PIN', onPressed: () {}),
            const SizedBox(height: 8),
            SecondaryButton(text: 'Forgot PIN', onPressed: () {}),
          ] else ...[
            PrimaryButton(text: 'Set up PIN', onPressed: () {}),
          ],
        ],
      ),
    );
  }
}

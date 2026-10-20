import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

/// Settings screen: exchange rate, categories, theme, app lock, sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';

    return ResponsiveBody(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    final settingAsync = ref.watch(settingsProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));

    return settingAsync.when(
      data: (setting) => categoriesAsync.when(
        data: (categories) {
          final effectiveSetting =
              setting ??
              const Setting(
                docId: 'main',
                usdToCdfRate: 280050,
                theme: 'light',
                displayMode: 'combined',
                onboarded: false,
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExchangeRateCard(effectiveSetting, ref),
              const SizedBox(height: 16),
              _buildCategoriesSection(categories, ref),
              const SizedBox(height: 24),
              _buildThemeCard(effectiveSetting, ref),
              const SizedBox(height: 16),
              _buildAppLockCard(context, ref),
              const SizedBox(height: 24),
              SecondaryButton(
                text: 'Sign out',
                onPressed: () => context.go(AppRoutes.signIn),
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (error, _) => ErrorBanner(message: error.toString()),
      ),
      loading: () => const SizedBox.shrink(),
      error: (error, _) => ErrorBanner(message: error.toString()),
    );
  }

  Widget _buildExchangeRateCard(Setting setting, WidgetRef ref) {
    final rateCtrl = TextEditingController(
      text: (setting.usdToCdfRate / 100).toStringAsFixed(2),
    );

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
            controller: rateCtrl,
            label: 'Rate (CDF per USD)',
            keyboardType: TextInputType.number,
            onChanged: (v) {},
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Save rate',
            onPressed: () {
              final text = rateCtrl.text
                  .replaceAll(',', '')
                  .replaceAll('.', '');
              try {
                final rateScaled = int.parse(text) * 100;
                ref
                    .read(settingsProvider(uid).notifier)
                    .save(setting.copyWith(usdToCdfRate: rateScaled));
              } catch (e) {
                // Error handled by settings provider
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(List<Category> categories, WidgetRef ref) {
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
                    onPressed: () => ref
                        .read(categoryProvider(uid).notifier)
                        .archive(cat.id, !cat.archived),
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

  Widget _buildThemeCard(Setting setting, WidgetRef ref) {
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
            selected: {setting.theme},
            onSelectionChanged: (selection) {
              ref
                  .read(settingsProvider(uid).notifier)
                  .save(setting.copyWith(theme: selection.first));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockCard(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(appLockProvider);
    final lockNotifier = ref.read(appLockProvider.notifier);

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
            value: lockState,
            onChanged: (v) async {
              if (v) {
                context.go(AppRoutes.pinSetup);
              } else {
                await lockNotifier.removePin();
              }
            },
          ),
          if (lockState) ...[
            SecondaryButton(
              text: 'Change PIN',
              onPressed: () => context.go(AppRoutes.pinSetup),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              text: 'Forgot PIN',
              onPressed: () async {
                await lockNotifier.removePin();
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(AppRoutes.signIn);
                }
              },
            ),
          ] else ...[
            PrimaryButton(
              text: 'Set up PIN',
              onPressed: () => context.go(AppRoutes.pinSetup),
            ),
          ],
        ],
      ),
    );
  }
}

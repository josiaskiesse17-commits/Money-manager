import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/settings/presentation/widgets/account_section.dart';
import 'package:money_manager/features/settings/presentation/widgets/appearance_section.dart';
import 'package:money_manager/features/settings/presentation/widgets/categories_section.dart';
import 'package:money_manager/features/settings/presentation/widgets/exchange_rate_section.dart';
import 'package:money_manager/features/settings/presentation/widgets/security_section.dart';
import 'package:money_manager/features/settings/presentation/widgets/settings_loading_card.dart';
import 'package:money_manager/features/settings/presentation/widgets/wallet_adjust_section.dart';

/// Settings screen: one card per section, in a single scrolling column.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return const ResponsiveBody(
        child: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final settingsAsync = ref.watch(settingsProvider(uid));
    final categoriesAsync = ref.watch(categoryProvider(uid));

    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;

    return ResponsiveBody(
      padding: EdgeInsets.only(
        left: isPhone ? 16 : 24,
        top: 0,
        right: isPhone ? 16 : 24,
        bottom: isPhone ? 16 : 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Settings',
                subtitle: 'Personalize your Money Manager experience.',
              ),
              const SizedBox(height: 16),
              settingsAsync.when(
                loading: () => const SettingsLoadingCard(
                  message: 'Loading your preferences…',
                ),
                error: (error, stackTrace) => ErrorBanner(
                  message: 'Could not load settings.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(settingsProvider(uid)),
                ),
                data: (setting) {
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
                      ExchangeRateSection(setting: effectiveSetting, uid: uid),
                      const SizedBox(height: 16),
                      AppearanceSection(setting: effectiveSetting, uid: uid),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              WalletAdjustSection(uid: uid),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () =>
                    const SettingsLoadingCard(message: 'Loading categories…'),
                error: (error, stackTrace) => ErrorBanner(
                  message: 'Could not load categories.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(categoryProvider(uid)),
                ),
                data: (categories) =>
                    CategoriesSection(categories: categories, uid: uid),
              ),
              const SizedBox(height: 16),
              const SecuritySection(),
              const SizedBox(height: 16),
              const AccountSection(),
            ],
          ),
        ),
      ),
    );
  }
}

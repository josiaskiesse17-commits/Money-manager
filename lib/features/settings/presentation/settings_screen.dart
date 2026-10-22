import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/settings/presentation/category_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _rateController = TextEditingController();
  final FocusNode _rateFocusNode = FocusNode();

  String? _controllerUid;
  String? _rateError;

  bool _savingRate = false;
  bool _showArchived = false;

  @override
  void dispose() {
    _rateController.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  void _syncRateController(String uid, Setting setting) {
    final formattedRate = (setting.usdToCdfRate / 100).toStringAsFixed(2);

    if (_controllerUid != uid) {
      _controllerUid = uid;
      _rateController.text = formattedRate;
      _rateError = null;
      return;
    }

    if (!_rateFocusNode.hasFocus &&
        !_savingRate &&
        _rateError == null &&
        _rateController.text != formattedRate) {
      _rateController.text = formattedRate;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      maxWidth: width >= 900 ? 1040 : null,
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
              const SizedBox(height: 20),
              settingsAsync.when(
                loading: () =>
                    const _LoadingCard(message: 'Loading your preferences…'),
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

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _syncRateController(uid, effectiveSetting);
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExchangeRateCard(effectiveSetting, uid),
                      const SizedBox(height: 20),
                      _buildThemeCard(effectiveSetting, uid),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              categoriesAsync.when(
                loading: () =>
                    const _LoadingCard(message: 'Loading categories…'),
                error: (error, stackTrace) => ErrorBanner(
                  message: 'Could not load categories.',
                  fix: 'Check your connection and try again.',
                  onRetry: () => ref.refresh(categoryProvider(uid)),
                ),
                data: (categories) =>
                    _buildCategoriesSection(context, categories, uid),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: const Text('Reports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.reports),
              ),
              const SizedBox(height: 20),
              _buildAppLockCard(context),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeRateCard(Setting setting, String uid) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final inputTextColor = isLight ? Colors.black87 : Colors.white;
    final secondaryTextColor = isLight ? Colors.black54 : Colors.white70;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Exchange rate',
              subtitle: 'Set the CDF value of one US dollar.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _rateController,
              focusNode: _rateFocusNode,
              style: TextStyle(color: inputTextColor),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'CDF per 1 USD',
                labelStyle: TextStyle(color: secondaryTextColor),
                floatingLabelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
                prefixIcon: Icon(
                  Icons.currency_exchange,
                  color: secondaryTextColor,
                ),
                helperText: 'Example: 2800.50',
                suffixText: 'CDF',
                suffixStyle: TextStyle(color: secondaryTextColor),
                errorText: _rateError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_rateError != null) {
                  setState(() {
                    _rateError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: 'Save exchange rate',
                busy: _savingRate,
                onPressed: _savingRate
                    ? null
                    : () => _saveExchangeRate(setting, uid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExchangeRate(Setting setting, String uid) async {
    if (_savingRate) return;

    final normalized = _rateController.text
        .trim()
        .replaceAll(',', '')
        .replaceAll(' ', '');

    final rate = double.tryParse(normalized);

    if (rate == null || !rate.isFinite || rate <= 0 || rate > 100000000) {
      setState(() {
        _rateError = 'Enter a valid exchange rate greater than zero.';
      });
      return;
    }

    final scaledRate = (rate * 100).round();

    setState(() {
      _savingRate = true;
      _rateError = null;
    });

    try {
      await ref
          .read(settingsProvider(uid).notifier)
          .save(setting.copyWith(usdToCdfRate: scaledRate));

      if (!mounted) return;

      _rateController.text = (scaledRate / 100).toStringAsFixed(2);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exchange rate saved successfully.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _rateError = 'Could not save the exchange rate. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingRate = false;
        });
      }
    }
  }

  Widget _buildThemeCard(Setting setting, String uid) {
    const supportedThemes = {'light', 'dark', 'system'};

    final theme = supportedThemes.contains(setting.theme)
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
                      _buildThemeOption(
                        icon: Icons.light_mode_outlined,
                        label: 'Light',
                        value: 'light',
                        selectedTheme: theme,
                        setting: setting,
                        uid: uid,
                      ),
                      const SizedBox(height: 8),
                      _buildThemeOption(
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark',
                        value: 'dark',
                        selectedTheme: theme,
                        setting: setting,
                        uid: uid,
                      ),
                      const SizedBox(height: 8),
                      _buildThemeOption(
                        icon: Icons.settings_suggest_outlined,
                        label: 'System',
                        value: 'system',
                        selectedTheme: theme,
                        setting: setting,
                        uid: uid,
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
                      _saveTheme(setting, uid, selection.first);
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

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required String value,
    required String selectedTheme,
    required Setting setting,
    required String uid,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = selectedTheme == value;

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _saveTheme(setting, uid, value),
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

  Future<void> _saveTheme(Setting setting, String uid, String theme) async {
    try {
      await ref
          .read(settingsProvider(uid).notifier)
          .save(setting.copyWith(theme: theme));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your theme preference.')),
      );
    }
  }

  Widget _buildCategoriesSection(
    BuildContext context,
    List<Category> categories,
    String uid,
  ) {
    final active = categories.where((category) => !category.archived).toList();
    final archived = categories.where((category) => category.archived).toList();
    final displayed = _showArchived ? categories : active;

    return Column(
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
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No categories yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add categories to organize your income and expenses.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
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
              child: _buildCategoryCard(context, category, uid),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: 'Add category',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const CategoryDialog(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Category category,
    String uid,
  ) {
    final color = Color(category.color);
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
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
                        category.name.isEmpty
                            ? 'Unnamed category'
                            : category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category.type == 'income' ? 'Income' : 'Expense',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (category.archived)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Archived',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 12,
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
                if (constraints.maxWidth < 320) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => CategoryDialog(category: category),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: Icon(
                          category.archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 18,
                        ),
                        label: Text(category.archived ? 'Restore' : 'Archive'),
                        onPressed: () => _toggleArchive(category, uid),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => CategoryDialog(category: category),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          category.archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 18,
                        ),
                        label: Text(category.archived ? 'Restore' : 'Archive'),
                        onPressed: () => _toggleArchive(category, uid),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleArchive(Category category, String uid) async {
    try {
      await ref
          .read(categoryProvider(uid).notifier)
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

  Widget _buildAppLockCard(BuildContext context) {
    final lockEnabled = ref.watch(appLockProvider);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'App lock',
              subtitle: 'Protect your app with a four-digit PIN.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable app lock'),
              subtitle: Text(
                lockEnabled ? 'A PIN is configured.' : 'No PIN is configured.',
              ),
              value: lockEnabled,
              onChanged: (enabled) {
                if (enabled) {
                  context.go(AppRoutes.pinSetup);
                } else {
                  _confirmRemovePin(context);
                }
              },
            ),
            if (lockEnabled) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.password),
                  label: const Text('Change PIN'),
                  onPressed: () => context.go(AppRoutes.pinSetup),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _confirmForgotPin(context),
                  child: const Text(
                    'Forgot PIN? Sign out and reset app lock',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Set up PIN',
                  onPressed: () => context.go(AppRoutes.pinSetup),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemovePin(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable app lock?'),
        content: const Text(
          'Your saved PIN will be removed from this device. '
          'You can set up a new PIN later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disable lock'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(appLockProvider.notifier).removePin();

      if (!mounted) return;

      ref.read(appLockRefreshProvider.notifier).state++;

      ScaffoldMessenger.of(this.context)
          .showSnackBar(const SnackBar(content: Text('App lock disabled.')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Could not disable app lock.')),
      );
    }
  }

  Future<void> _confirmForgotPin(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your app lock?'),
        content: const Text(
          'You will be signed out and your saved PIN will be removed '
          'from this device. You can sign in again and create a new PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out and reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(appLockProvider.notifier).removePin();

      if (!mounted) return;

      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;

      ref.read(appLockRefreshProvider.notifier).state++;

      this.context.go(AppRoutes.signIn);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Could not reset the app lock.')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;

      this.context.go(AppRoutes.signIn);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

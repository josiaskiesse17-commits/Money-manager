import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';

/// Security section: the app lock PIN.
class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  Future<void> _confirmRemovePin(BuildContext context, WidgetRef ref) async {
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

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(appLockProvider.notifier).removePin();

      if (!context.mounted) return;

      ref.read(appLockRefreshProvider.notifier).state++;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('App lock disabled.')));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not disable app lock.')),
      );
    }
  }

  Future<void> _confirmForgotPin(BuildContext context, WidgetRef ref) async {
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

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(appLockProvider.notifier).removePin();

      if (!context.mounted) return;

      await ref.read(authProvider.notifier).signOut();

      if (!context.mounted) return;

      ref.read(appLockRefreshProvider.notifier).state++;

      context.go(AppRoutes.signIn);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reset the app lock.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(appLockProvider);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Security',
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
                  _confirmRemovePin(context, ref);
                }
              },
            ),
            if (lockEnabled) ...[
              const SizedBox(height: 8),
              SecondaryButton(
                text: 'Change PIN',
                onPressed: () => context.go(AppRoutes.pinSetup),
              ),
              const SizedBox(height: 4),
              SecondaryButton(
                text: 'Forgot PIN? Sign out and reset app lock',
                onPressed: () => _confirmForgotPin(context, ref),
              ),
            ] else ...[
              const SizedBox(height: 8),
              PrimaryButton(
                text: 'Set up PIN',
                onPressed: () => context.go(AppRoutes.pinSetup),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

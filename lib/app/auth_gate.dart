import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/auth/presentation/sign_in_screen.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';
import 'package:money_manager/features/onboarding/presentation/first_run_setup.dart';

/// Gate above everything: loading -> sign-in -> first-run setup -> Home.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    return user == null
        ? const SignInScreen()
        : Consumer(
            builder: (_, ref, _) {
              final settings = ref.watch(settingsProvider(user.uid));
              return settings.when(
                data: (setting) {
                  if (setting == null || !setting.onboarded) {
                    return const FirstRunSetup();
                  }
                  return AppShell(
                    currentRoute: AppRoutes.home,
                    child: const HomeScreen(),
                  );
                },
                loading: () =>
                    const Scaffold(body: Center(child: Text('Loading...'))),
                error: (error, stack) => Scaffold(
                  body: Center(
                    child: ErrorBanner(
                      message: 'Failed to load settings.',
                      fix: 'Check your internet connection and try again.',
                      onRetry: () => ref.refresh(settingsProvider(user.uid)),
                    ),
                  ),
                ),
              );
            },
          );
  }
}

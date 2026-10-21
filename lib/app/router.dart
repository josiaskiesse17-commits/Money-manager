import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/auth_gate.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/auth/presentation/reset_password_screen.dart';
import 'package:money_manager/features/auth/presentation/sign_up_screen.dart';
import 'package:money_manager/features/budgets/presentation/budgets_screen.dart';
import 'package:money_manager/features/convert/presentation/convert_screen.dart';
import 'package:money_manager/features/charts/presentation/charts_screen.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/reports/presentation/report_screen.dart';
import 'package:money_manager/features/settings/presentation/pin_setup_screen.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';
import 'package:money_manager/features/transactions/presentation/transaction_list_screen.dart';

/// Routes that remain open to signed-out or unverified users.
final _openRoutes = <String>{
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.resetPassword,
};

/// App routes — go_router configuration using named constants from [AppRoutes].
///
/// The [redirect] guard prevents signed-out and unverified users from
/// reaching protected routes.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.signIn,
    redirect: (context, state) {
      final user = ref.read(authProvider);
      final isOpen = _openRoutes.contains(state.matchedLocation);

      if (user == null) {
        return isOpen ? null : AppRoutes.signIn;
      }

      if (!user.emailVerified) {
        return isOpen ? null : AppRoutes.signIn;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const AuthGate()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (_, _) => AppShell(
          currentRoute: AppRoutes.transactions,
          child: const TransactionsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.convert,
        builder: (_, _) => const ConvertScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) =>
            AppShell(currentRoute: AppRoutes.home, child: const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.budgets,
        builder: (_, _) => AppShell(
          currentRoute: AppRoutes.budgets,
          child: const BudgetsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.charts,
        builder: (_, _) => AppShell(
          currentRoute: AppRoutes.charts,
          child: const ChartsScreen(),
        ),
      ),
      GoRoute(path: AppRoutes.reports, builder: (_, _) => const ReportScreen()),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => AppShell(
          currentRoute: AppRoutes.settings,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (_, _) => const PinSetupScreen(),
      ),
    ],
  );
});

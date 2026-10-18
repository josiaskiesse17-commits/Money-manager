import 'package:go_router/go_router.dart';
import 'package:money_manager/app/auth_gate.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/features/auth/presentation/reset_password_screen.dart';
import 'package:money_manager/features/auth/presentation/sign_up_screen.dart';
import 'package:money_manager/features/budgets/presentation/budgets_screen.dart';
import 'package:money_manager/features/convert/presentation/convert_screen.dart';
import 'package:money_manager/features/charts/presentation/charts_screen.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/reports/presentation/report_screen.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';
import 'package:money_manager/features/transactions/presentation/transaction_list_screen.dart';

/// App routes — go_router configuration using named constants from [AppRoutes].
final router = GoRouter(
  initialLocation: AppRoutes.signIn,
  routes: [
    GoRoute(path: AppRoutes.signIn, builder: (_, _) => const AuthGate()),
    GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
    GoRoute(
      path: AppRoutes.resetPassword,
      builder: (_, _) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.transactions,
      builder: (_, _) => const TransactionsScreen(),
    ),
    GoRoute(path: AppRoutes.convert, builder: (_, _) => const ConvertScreen()),
    GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(path: AppRoutes.budgets, builder: (_, _) => const BudgetsScreen()),
    GoRoute(path: AppRoutes.charts, builder: (_, _) => const ChartsScreen()),
    GoRoute(path: AppRoutes.reports, builder: (_, _) => const ReportScreen()),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
  ],
);

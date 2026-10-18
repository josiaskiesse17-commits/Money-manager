import 'package:go_router/go_router.dart';
import 'package:money_manager/app/auth_gate.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/features/auth/presentation/reset_password_screen.dart';
import 'package:money_manager/features/auth/presentation/sign_up_screen.dart';

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
  ],
);

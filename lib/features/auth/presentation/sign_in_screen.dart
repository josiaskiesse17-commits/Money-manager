import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/auth_layout.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final errorMessage = ref.watch(authProvider.notifier).signInError;
    final busy = ref.watch(authProvider.notifier).busy;

    return AuthLayout(
      title: 'Sign in',
      subtitle: 'Track CDF and USD in one place.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorMessage != null) ...[
              ErrorBanner(message: errorMessage),
              const SizedBox(height: 16),
            ],
            AppTextField(
              controller: emailCtrl,
              label: 'Email',
              autofillHint: AutofillHints.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: passwordCtrl,
              label: 'Password',
              obscureText: true,
              autofillHint: AutofillHints.password,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter password' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: SecondaryButton(
                text: 'Forgot password?',
                onPressed: () => context.go(AppRoutes.resetPassword),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Sign in',
              busy: busy,
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        await ref
                            .read(authProvider.notifier)
                            .signIn(emailCtrl.text, passwordCtrl.text);
                      } catch (e) {
                        reportError(e, userMessage: 'Wrong email or password.');
                      }
                    },
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'or',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              text: 'Create an account',
              onPressed: () => context.go(AppRoutes.signUp),
            ),
          ],
        ),
      ),
    );
  }
}

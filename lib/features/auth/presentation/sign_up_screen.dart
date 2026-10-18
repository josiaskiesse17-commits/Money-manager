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

class SignUpScreen extends ConsumerWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final errorMessage = ref.watch(authProvider.notifier).signUpError;
    final busy = ref.watch(authProvider.notifier).busy;

    return AuthLayout(
      title: 'Create an account',
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
              autofillHint: AutofillHints.newPassword,
              helperText: 'At least 6 characters',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter password';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: confirmCtrl,
              label: 'Confirm password',
              obscureText: true,
              autofillHint: AutofillHints.newPassword,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your password';
                if (v != passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Create account',
              busy: busy,
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        await ref
                            .read(authProvider.notifier)
                            .signUp(emailCtrl.text, passwordCtrl.text);
                      } catch (e) {
                        reportError(e, userMessage: 'Sign up failed.');
                      }
                    },
            ),
            const SizedBox(height: 20),
            Center(
              child: SecondaryButton(
                text: 'I already have an account',
                onPressed: () => context.go(AppRoutes.signIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

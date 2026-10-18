import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/app_text_field.dart';
import 'package:money_manager/app/widgets/auth_layout.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref
          .read(authProvider.notifier)
          .resetPassword(_emailCtrl.text.trim());
    } catch (e) {
      reportError(e, userMessage: 'Password reset failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider.notifier);
    final sent = auth.resetSent;
    final busy = auth.busy;
    final errorMessage = auth.resetError;

    return AuthLayout(
      title: 'Reset password',
      subtitle: 'Track CDF and USD in one place.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!sent) ...[
            if (errorMessage != null) ...[
              ErrorBanner(message: errorMessage),
              const SizedBox(height: 20),
            ],
            const Text(
              'Enter your email to receive a password reset link.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _emailCtrl,
              label: 'Email',
              autofillHint: AutofillHints.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Send reset link',
              busy: busy,
              onPressed: busy ? null : _submit,
            ),
            const SizedBox(height: 20),
            Center(
              child: SecondaryButton(
                text: 'Back to sign in',
                onPressed: busy ? null : () => context.go(AppRoutes.signIn),
              ),
            ),
          ] else ...[
            const Text(
              'Check your inbox. If the email has an account, a link is on its way.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SecondaryButton(
              text: 'Back to sign in',
              onPressed: () => context.go(AppRoutes.signIn),
            ),
          ],
        ],
      ),
    );
  }
}

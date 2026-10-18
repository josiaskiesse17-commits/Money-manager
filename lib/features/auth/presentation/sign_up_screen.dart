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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    try {
      await ref
          .read(authProvider.notifier)
          .signUp(_emailCtrl.text.trim(), _passwordCtrl.text);
    } catch (e) {
      reportError(e, userMessage: 'Sign up failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider.notifier);
    final errorMessage = auth.signUpError;
    final busy = auth.busy;
    final colors = Theme.of(context).colorScheme;

    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Start managing your CDF and USD finances.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMessage != null) ...[
                ErrorBanner(message: errorMessage),
                const SizedBox(height: 20),
              ],
              AppTextField(
                controller: _emailCtrl,
                label: 'Email address',
                autofillHint: AutofillHints.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _passwordCtrl,
                label: 'Password',
                obscureText: true,
                autofillHint: AutofillHints.newPassword,
                helperText: 'Use at least 6 characters.',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must contain at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _confirmCtrl,
                label: 'Confirm password',
                obscureText: true,
                autofillHint: AutofillHints.newPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password';
                  }
                  if (value != _passwordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                text: 'Create account',
                busy: busy,
                onPressed: busy ? null : _submit,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: colors.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ALREADY REGISTERED?',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.outlineVariant)),
                ],
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                text: 'Sign in instead',
                onPressed: busy ? null : () => context.go(AppRoutes.signIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

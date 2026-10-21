import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/widgets/auth_layout.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';

/// Cooldown between verification-email resend taps, matching Firebase's
/// rate limit for sendEmailVerification.
const _resendCooldown = Duration(seconds: 60);

/// Verification screen shown to signed-in users whose email is not yet
/// verified. They cannot enter the protected application until
/// [User.emailVerified] becomes true.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  DateTime? _lastResend;

  bool get _inCooldown {
    if (_lastResend == null) return false;
    return DateTime.now().difference(_lastResend!) < _resendCooldown;
  }

  int get _cooldownSeconds {
    if (_lastResend == null) return 0;
    final remaining =
        _resendCooldown.inSeconds -
        DateTime.now().difference(_lastResend!).inSeconds;
    return remaining.clamp(0, _resendCooldown.inSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider.notifier);
    final user = ref.watch(authProvider);
    final email = user?.email;

    final busy = auth.verificationBusy;
    final error = auth.verificationError;
    final colors = Theme.of(context).colorScheme;

    return AuthLayout(
      title: 'Verify your email',
      subtitle:
          'A verification email has been sent to ${email ?? 'your email address'}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            ErrorBanner(message: error),
            const SizedBox(height: 20),
          ],
          const Text(
            'Open your email inbox, click the verification link, then tap '
            '"Check again" to continue.',
          ),
          const SizedBox(height: 24),
          if (_inCooldown) ...[
            Text(
              'Resend again in ${_cooldownSeconds}s',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          PrimaryButton(
            text: 'Check again',
            busy: busy,
            onPressed: busy ? null : auth.reloadUser,
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            text: 'Resend verification email',
            onPressed: busy || _inCooldown
                ? null
                : () async {
                    await auth.sendEmailVerification();
                    if (mounted) setState(() => _lastResend = DateTime.now());
                  },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: colors.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colors.outlineVariant)),
            ],
          ),
          const SizedBox(height: 20),
          SecondaryButton(
            text: 'Sign out',
            onPressed: busy ? null : () => auth.signOut(),
          ),
        ],
      ),
    );
  }
}

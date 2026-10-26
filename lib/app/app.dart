import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/router.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  WidgetRef? _ref;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ref = _ref;

    if (ref == null) return;

    final notifier = ref.read(appLockProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        notifier.didEnterBackground();
        break;

      case AppLifecycleState.resumed:
        if (notifier.checkBackgroundLock()) {
          notifier.lock();

          // Rebuild the root so the lock screen is displayed.
          ref.read(appLockRefreshProvider.notifier).state++;
        }
        break;

      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        _ref = ref;

        final lockEnabled = ref.watch(appLockProvider);

        // This subscription rebuilds MaterialApp when the lock screen
        // is opened or dismissed.
        ref.watch(appLockRefreshProvider);

        final user = ref.watch(authProvider);
        final uid = user?.uid ?? '';

        var themeMode = ThemeMode.system;

        if (uid.isNotEmpty) {
          final settingsAsync = ref.watch(settingsProvider(uid));
          final theme = settingsAsync.valueOrNull?.theme;

          switch (theme) {
            case 'light':
              themeMode = ThemeMode.light;
              break;

            case 'dark':
              themeMode = ThemeMode.dark;
              break;

            case 'system':
            default:
              themeMode = ThemeMode.system;
          }
        }

        final lockNotifier = ref.read(appLockProvider.notifier);

        return MaterialApp.router(
          routerConfig: ref.watch(routerProvider),
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Money Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          builder: (context, child) {
            if (lockEnabled && lockNotifier.isLocked) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: appSystemOverlayStyle(context),
                child: const _LockScreenContent(),
              );
            }

            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _LockScreenContent extends ConsumerStatefulWidget {
  const _LockScreenContent();

  @override
  ConsumerState<_LockScreenContent> createState() => _LockScreenContentState();
}

class _LockScreenContentState extends ConsumerState<_LockScreenContent> {
  final TextEditingController _pinCtrl = TextEditingController();

  String? _error;
  bool _authenticating = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;

    final pin = _pinCtrl.text;

    if (pin.length != 4) {
      setState(() => _error = 'Enter all four digits.');
      return;
    }

    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final notifier = ref.read(appLockProvider.notifier);
      final verified = await notifier.unlock(pin);

      if (!mounted) return;

      if (verified) {
        _pinCtrl.clear();

        // Rebuild MaterialApp so its builder removes the lock screen.
        ref.read(appLockRefreshProvider.notifier).state++;
      } else {
        _pinCtrl.clear();
        setState(() => _error = 'Incorrect PIN. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  Future<void> _tryBiometrics() async {
    if (_authenticating) return;

    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final notifier = ref.read(appLockProvider.notifier);
      final success = await notifier.unlockWithBiometrics();

      if (!mounted) return;

      if (success) {
        ref.read(appLockRefreshProvider.notifier).state++;
      } else {
        setState(
          () => _error = 'Biometric authentication failed or is unavailable.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot your PIN?'),
        content: const Text(
          'You will be signed out and the saved PIN will be removed '
          'from this device. You can sign in again and set up a new PIN.',
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

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(appLockProvider.notifier).removePin();

      if (!mounted) return;

      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;

      ref.read(appLockRefreshProvider.notifier).state++;
      context.go(AppRoutes.signIn);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not reset the app lock. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appSystemOverlayStyle(context),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 44,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Money Manager',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to continue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < _pinCtrl.text.length;

                        return Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: filled
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _pinCtrl,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      enabled: !_authenticating,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                      decoration: const InputDecoration(
                        labelText: 'Four-digit PIN',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _error = null);

                        if (value.length == 4) {
                          _unlock();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _authenticating ? null : _unlock,
                        child: _authenticating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SecondaryButton(
                          text: 'Use biometrics',
                          onPressed: _authenticating ? null : _tryBiometrics,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _authenticating ? null : _forgotPin,
                      child: const Text('Forgot PIN?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/router.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';

/// Root app widget with lifecycle observation for background lock.
///
/// Detects app going to background and locks after 15 seconds.
/// When locked, shows the lock screen instead of the app.
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
    final notifier = _ref!.read(appLockProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        notifier.didEnterBackground();
        break;
      case AppLifecycleState.resumed:
        if (notifier.checkBackgroundLock()) {
          notifier.lock();
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
        final lockState = ref.watch(appLockProvider);

        return MaterialApp.router(
          routerConfig: router,
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Money Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          builder: (context, child) {
            if (lockState) {
              return const _LockScreenContent();
            }
            return child!;
          },
        );
      },
    );
  }
}

/// Lock screen content with state for PIN input.
class _LockScreenContent extends ConsumerStatefulWidget {
  const _LockScreenContent();

  @override
  ConsumerState<_LockScreenContent> createState() => _LockScreenContentState();
}

class _LockScreenContentState extends ConsumerState<_LockScreenContent> {
  final _pinCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final pin = _pinCtrl.text;
    if (pin.length != 4) {
      setState(() => _error = 'Enter 4 digits');
      return;
    }

    final notifier = ref.read(appLockProvider.notifier);
    final verified = await notifier.unlock(pin);
    if (!mounted) return;

    if (verified) {
      setState(() => _error = null);
      _pinCtrl.clear();
    } else {
      setState(() => _error = 'Wrong PIN');
      _pinCtrl.clear();
    }
  }

  Future<void> _tryBiometrics() async {
    final notifier = ref.read(appLockProvider.notifier);
    final ok = await notifier.unlockWithBiometrics();
    if (!mounted) return;

    if (!ok) {
      setState(
        () => _error = 'Biometrics unavailable or authentication failed',
      );
    }
  }

  Future<void> _forgotPin() async {
    final notifier = ref.read(appLockProvider.notifier);
    await notifier.removePin();
    if (!mounted) return;

    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    context.go(AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final hasBiometrics = !kIsWeb;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'App Lock',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your PIN to continue',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error
                          .withValues(alpha: 0.1),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error
                            .withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _pinCtrl.text.length;
                    return Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: filled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (v) {
                    if (v.length == 4) {
                      _unlock();
                    }
                  },
                ),
                const SizedBox(height: 24),
                if (hasBiometrics) ...[
                  SecondaryButton(
                    text: 'Use Biometrics',
                    onPressed: _tryBiometrics,
                  ),
                  const SizedBox(height: 16),
                ],
                SecondaryButton(text: 'Forgot PIN', onPressed: _forgotPin),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _focusNode = FocusNode();

  String _stage = 'loading';
  String? _error;
  String _currentPin = '';
  String _newPin = '';
  bool _saving = false;
  bool _initialized = false;

  bool get _changingPin => _currentPin.isNotEmpty;

  bool get _isCurrentPinStage => _stage == 'current';

  bool get _isCreateStage => _stage == 'create';

  bool get _isConfirmStage => _stage == 'confirm';

  TextEditingController get _activeController {
    return _isConfirmStage ? _confirmationController : _pinController;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final notifier = ref.read(appLockProvider.notifier);

    // Wait for the stored PIN to finish loading before choosing the flow.
    while (!notifier.hasLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;
    }

    if (!mounted) return;

    final hasPin = ref.read(appLockProvider);

    setState(() {
      _stage = hasPin ? 'current' : 'create';
      _initialized = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  void _setStage(String stage) {
    setState(() {
      _stage = stage;
      _error = null;
      _pinController.clear();
      _confirmationController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _continue() async {
    if (_saving) return;

    final pin = _activeController.text;

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Please enter exactly four digits.');
      return;
    }

    if (_isCurrentPinStage) {
      setState(() => _saving = true);

      try {
        final valid = await ref.read(appLockProvider.notifier).verifyPin(pin);

        if (!mounted) return;

        if (!valid) {
          _pinController.clear();
          setState(() {
            _error = 'Your current PIN is incorrect. Please try again.';
          });
          return;
        }

        _currentPin = pin;
        _setStage('create');
      } catch (_) {
        if (mounted) {
          setState(() {
            _error = 'Could not verify your PIN. Please try again.';
          });
        }
      } finally {
        if (mounted) {
          setState(() => _saving = false);
        }
      }

      return;
    }

    if (_isCreateStage) {
      _newPin = pin;
      _setStage('confirm');
      return;
    }

    if (_isConfirmStage) {
      if (pin != _newPin) {
        _confirmationController.clear();

        setState(() {
          _error = 'The PINs do not match. Please try again.';
        });

        return;
      }

      await _savePin(pin);
    }
  }

  Future<void> _savePin(String confirmedPin) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(appLockProvider.notifier);

      if (_changingPin) {
        final changed = await notifier.changePin(_currentPin, confirmedPin);

        if (!changed) {
          if (!mounted) return;

          setState(() {
            _stage = 'current';
            _currentPin = '';
            _newPin = '';
            _pinController.clear();
            _confirmationController.clear();
            _error = 'Your PIN could not be changed. Please verify your current PIN again.';
          });

          return;
        }
      } else {
        await notifier.setupPin(confirmedPin);
      }

      if (!mounted) return;

      ref.read(appLockRefreshProvider.notifier).state++;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _changingPin
                ? 'Your PIN has been changed successfully.'
                : 'Your app PIN has been set up successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.go(AppRoutes.settings);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not save your PIN. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _goBack() {
    if (_saving) return;

    if (_isConfirmStage) {
      _setStage('create');
      return;
    }

    if (_isCreateStage && _changingPin) {
      _setStage('current');
      _currentPin = '';
      _newPin = '';
      return;
    }

    context.go(AppRoutes.settings);
  }

  String get _title {
    if (_isCurrentPinStage) return 'Verify your PIN';
    if (_isCreateStage) {
      return _changingPin ? 'Create a new PIN' : 'Create your PIN';
    }
    if (_isConfirmStage) return 'Confirm your PIN';
    return 'App lock';
  }

  String get _subtitle {
    if (_isCurrentPinStage) {
      return 'Enter your current four-digit PIN to continue.';
    }

    if (_isCreateStage) {
      return 'Choose a four-digit PIN to protect your finances.';
    }

    if (_isConfirmStage) {
      return 'Enter your new PIN once more to confirm it.';
    }

    return 'Preparing your secure PIN settings...';
  }

  String get _buttonLabel {
    if (_isCurrentPinStage) return 'Verify PIN';
    if (_isCreateStage) return 'Continue';
    return 'Save PIN';
  }

  int get _step {
    if (_isCurrentPinStage) return 1;
    if (_isCreateStage) return _changingPin ? 2 : 1;
    return _changingPin ? 3 : 2;
  }

  int get _totalSteps => _changingPin ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_changingPin ? 'Change PIN' : 'Set up app lock'),
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: _saving ? null : _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          child: !_initialized
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Icon(
                                _isCurrentPinStage
                                    ? Icons.verified_user_rounded
                                    : Icons.lock_outline_rounded,
                                size: 42,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: List.generate(_totalSteps, (index) {
                              final completed = index < _step;

                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 5,
                                  margin: EdgeInsets.only(
                                    right: index == _totalSteps - 1 ? 0 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? colors.primary
                                        : colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'STEP $_step OF $_totalSteps',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            key: ValueKey(_stage),
                            controller: _activeController,
                            focusNode: _focusNode,
                            autofocus: true,
                            enabled: !_saving,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            textAlign: TextAlign.center,
                            maxLength: 4,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            style: const TextStyle(
                              fontSize: 26,
                              letterSpacing: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: _isCurrentPinStage
                                  ? 'Current PIN'
                                  : _isConfirmStage
                                  ? 'Confirm new PIN'
                                  : 'Four-digit PIN',
                              counterText: '',
                              prefixIcon: const Icon(Icons.password_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colors.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearError(),
                            onSubmitted: (_) => _continue(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final filled =
                                  index < _activeController.text.length;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: filled ? 16 : 13,
                                height: filled ? 16 : 13,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: filled
                                      ? colors.primary
                                      : colors.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: filled
                                        ? colors.primary
                                        : colors.outlineVariant,
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: colors.onErrorContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: colors.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          PrimaryButton(
                            text: _buttonLabel,
                            busy: _saving,
                            onPressed: _saving ? null : _continue,
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            text: 'Cancel',
                            onPressed: _saving ? null : _goBack,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your PIN is stored as a secure hash on this device. Choose a PIN you can remember.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
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

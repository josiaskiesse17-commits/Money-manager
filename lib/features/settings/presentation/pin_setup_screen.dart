import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';
import 'package:money_manager/app/widgets/section_header.dart';
import 'package:money_manager/features/settings/application/app_lock_provider.dart';

/// PIN setup screen: create a 4-digit PIN by entering it twice.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinCtrl1 = TextEditingController();
  final _pinCtrl2 = TextEditingController();
  String? _error;
  String _stage = 'create'; // 'create' | 'confirm'

  @override
  void dispose() {
    _pinCtrl1.dispose();
    _pinCtrl2.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final pin1 = _pinCtrl1.text;
    final pin2 = _pinCtrl2.text;

    if (pin1.length != 4 || pin2.length != 4) {
      setState(() => _error = 'Enter 4 digits in both fields');
      return;
    }

    if (pin1 != pin2) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    final notifier = ref.read(appLockProvider.notifier);
    await notifier.setupPin(pin1);
    if (!mounted) return;

    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final creating = _stage == 'create';

    final children = <Widget>[
      const SectionHeader(
        title: 'Set up app lock',
        subtitle: 'Choose a 4-digit PIN to protect your data.',
      ),
      const SizedBox(height: 24),
    ];

    if (_error != null) {
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 24));

    children.add(
      TextField(
        controller: _pinCtrl1,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(
          labelText: creating ? 'Enter PIN' : 'Confirm PIN',
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (v) {
          if (creating && v.length == 4) {
            setState(() => _stage = 'confirm');
          }
        },
      ),
    );

    children.add(const SizedBox(height: 24));

    children.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final filled = index < _pinCtrl1.text.length;
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
    );

    children.add(const SizedBox(height: 32));

    children.add(
      Row(
        children: [
          Expanded(
            child: PrimaryButton(
              text: creating ? 'Next' : 'Save PIN',
              onPressed: () {
                if (creating) {
                  if (_pinCtrl1.text.length == 4) {
                    setState(() => _stage = 'confirm');
                    _pinCtrl2.text = '';
                  }
                } else {
                  _savePin();
                }
              },
            ),
          ),
        ],
      ),
    );

    if (!creating) {
      children.add(const SizedBox(height: 16));
      children.add(
        SecondaryButton(
          text: 'Cancel',
          onPressed: () => context.go(AppRoutes.settings),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(creating ? 'Create PIN' : 'Confirm PIN')),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

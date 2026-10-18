import 'package:flutter/material.dart';
import 'package:money_manager/app/widgets/secondary_button.dart';

/// Numeric amount keypad for transaction forms.
///
/// - [currency] 'CDF': no decimal key, whole numbers only
/// - [currency] 'USD': decimal key, max 2 decimals, max 12 digits
/// Emits the current minor-unit amount via [onAmountChanged].
class AmountKeypad extends StatefulWidget {
  final String currency; // 'CDF' | 'USD'
  final int initialAmount; // minor units
  final ValueChanged<int> onAmountChanged;

  const AmountKeypad({
    super.key,
    required this.currency,
    this.initialAmount = 0,
    required this.onAmountChanged,
  });

  @override
  State<AmountKeypad> createState() => _AmountKeypadState();
}

class _AmountKeypadState extends State<AmountKeypad> {
  late int _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount;
  }

  void _appendDigit(int digit) {
    if (widget.currency == 'CDF') {
      if (_amount >= 99999999999) return;
      setState(() => _amount = _amount * 10 + digit);
    } else {
      final cents = _amount;
      final dollars = cents ~/ 100;
      final rem = cents % 100;
      final newDollars = dollars * 10 + digit;
      if (newDollars > 9999999999) return;
      setState(() => _amount = newDollars * 100 + rem);
    }
  }

  void _appendDecimal() {
    if (widget.currency == 'CDF') return;
    final cents = _amount;
    final dollars = cents ~/ 100;
    final rem = cents % 100;
    if (rem >= 10) return;
    setState(() => _amount = dollars * 100 + rem * 10);
  }

  void _backspace() {
    if (widget.currency == 'CDF') {
      setState(() => _amount = _amount ~/ 10);
    } else {
      final cents = _amount;
      final dollars = cents ~/ 100;
      final rem = cents % 100;
      final newDollars = dollars ~/ 10;
      setState(() => _amount = newDollars * 100 + rem);
    }
  }

  void _clear() {
    setState(() => _amount = 0);
  }

  @override
  Widget build(BuildContext context) {
    widget.onAmountChanged(_amount);

    final display = switch (widget.currency) {
      'USD' => '\$${(_amount / 100).toStringAsFixed(2)}',
      'CDF' => '${_amount.toString()} FC',
      _ => '$_amount',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SecondaryButton(text: 'Clear', onPressed: _clear),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: widget.currency == 'CDF' ? 11 : 12,
          itemBuilder: (_, index) {
            if (widget.currency == 'CDF' && index == 10) {
              return _key('⌫', Icons.backspace, _backspace);
            }
            if (widget.currency == 'USD' && index == 11) {
              return _key('⌫', Icons.backspace, _backspace);
            }
            if (widget.currency == 'USD' && index == 10) {
              return _key('.', null, _appendDecimal);
            }
            return _key('$index', null, () => _appendDigit(index));
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _key(String label, IconData? icon, VoidCallback onPressed) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: icon != null
            ? Icon(icon, size: 24)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

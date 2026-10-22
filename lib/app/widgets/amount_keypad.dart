import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:money_manager/core/money/currency.dart';
import 'package:money_manager/core/money/money.dart';

/// Numeric amount keypad for transaction forms.
///
/// CDF: whole numbers only.
/// USD: amounts stored as minor units (cents).
///
/// Notifies the parent only when the amount changes.
class AmountKeypad extends StatefulWidget {
  final String currency;
  final int initialAmount;
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

  @override
  void didUpdateWidget(covariant AmountKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currency != widget.currency ||
        oldWidget.initialAmount != widget.initialAmount) {
      _amount = widget.initialAmount;
    }
  }

  void _updateAmount(int amount) {
    if (amount == _amount) return;

    setState(() {
      _amount = amount;
    });

    widget.onAmountChanged(_amount);
  }

  void _appendDigit(int digit) {
    if (widget.currency == 'CDF') {
      if (_amount > (99999999999 - digit) ~/ 10) return;

      _updateAmount(_amount * 10 + digit);
      return;
    }

    final dollars = _amount ~/ 100;
    final cents = _amount % 100;
    final newDollars = dollars * 10 + digit;

    if (newDollars > 9999999999) return;

    _updateAmount(newDollars * 100 + cents);
  }

  void _appendDecimal() {
    if (widget.currency != 'USD') return;

    final dollars = _amount ~/ 100;
    final cents = _amount % 100;

    if (cents >= 10) return;

    _updateAmount(dollars * 100 + cents * 10);
  }

  void _backspace() {
    if (widget.currency == 'CDF') {
      _updateAmount(_amount ~/ 10);
      return;
    }

    final dollars = _amount ~/ 100;
    final cents = _amount % 100;

    _updateAmount((dollars ~/ 10) * 100 + cents);
  }

  void _clear() {
    _updateAmount(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final display = Money(
      amount: _amount,
      currency: widget.currency == 'USD' ? Currency.usd : Currency.cdf,
    ).format();

    // Standard numeric layout. CDF uses the same grid with the decimal
    // position replaced by an empty space.
    final keys = <_KeyData>[
      _KeyData('1', () => _appendDigit(1)),
      _KeyData('2', () => _appendDigit(2)),
      _KeyData('3', () => _appendDigit(3)),
      _KeyData('4', () => _appendDigit(4)),
      _KeyData('5', () => _appendDigit(5)),
      _KeyData('6', () => _appendDigit(6)),
      _KeyData('7', () => _appendDigit(7)),
      _KeyData('8', () => _appendDigit(8)),
      _KeyData('9', () => _appendDigit(9)),
      if (widget.currency == 'USD')
        _KeyData('.', _appendDecimal)
      else
        _KeyData('C', _clear, icon: Icons.clear_rounded),
      _KeyData('0', () => _appendDigit(0)),
      _KeyData('⌫', _backspace, icon: Icons.backspace_outlined, isAction: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 420.0;

        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;

        final compact = height < 360;

        final outerPadding = compact ? 4.0 : 6.0;
        final gap = compact ? 6.0 : 8.0;
        final displayHeight = compact ? 58.0 : 68.0;

        // Reserve space for the amount display, spacing, and grid.
        final gridHeight = math.max(
          0.0,
          height - displayHeight - gap - outerPadding * 2,
        );

        final keyWidth = (width - outerPadding * 2 - gap * 2) / 3;
        final keyHeight = (gridHeight - gap * 3) / 4;

        return Padding(
          padding: EdgeInsets.all(outerPadding),
          child: Column(
            children: [
              Container(
                height: displayHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          display,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Clear amount',
                      onPressed: _clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: keys.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    mainAxisExtent: math.max(
                      1.0,
                      math.min(keyHeight, keyWidth / 0.8),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final key = keys[index];

                    return _buildKey(
                      context,
                      label: key.label,
                      icon: key.icon,
                      onPressed: key.onPressed,
                      isAction: key.isAction,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKey(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isAction = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox.expand(
      child: Material(
        color: isAction
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 23,
                    color: isAction
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  )
                : Text(
                    label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _KeyData {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isAction;

  const _KeyData(
    this.label,
    this.onPressed, {
    this.icon,
    this.isAction = false,
  });
}

import 'package:flutter/material.dart';
import 'package:money_manager/app/theme.dart';

/// Amount text: tabular figures, signed (+ / -), colored for income/expense.
class AmountText extends StatelessWidget {
  final int amount; // minor units
  final String currency; // CDF | USD
  final bool showSign;
  final double? fontSize;
  final FontWeight? fontWeight;

  const AmountText({
    super.key,
    required this.amount,
    required this.currency,
    this.showSign = false,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = amount >= 0;
    final absAmount = amount.abs();

    final text = switch (currency) {
      'USD' =>
        '\$${_format(absAmount ~/ 100)}.${(absAmount % 100).toString().padLeft(2, '0')}',
      'CDF' => '${_format(absAmount)} FC',
      _ => '$absAmount',
    };

    final signedText = showSign && amount != 0
        ? (isIncome ? '+$text' : '-$text')
        : text;

    final moneyColors = Theme.of(context).extension<MoneyColors>();
    final color = amount == 0
        ? null
        : (isIncome ? moneyColors?.income : moneyColors?.expense);

    return Text(
      signedText,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  String _format(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/features/home/application/home_totals.dart';

String formatMinorAmount(int amount, String currency) {
  final negative = amount < 0;
  final abs = amount.abs();
  final text = currency == 'USD'
      ? '\$${NumberFormat('#,##0.00').format(abs / 100)}'
      : '${NumberFormat('#,##0').format(abs)} FC';
  return negative ? '-$text' : text;
}

class CombinedTotalCard extends StatelessWidget {
  const CombinedTotalCard({
    super.key,
    required this.cdfWallet,
    required this.usdWallet,
    required this.rateScaled,
    required this.displayMode,
  });

  final Wallet? cdfWallet;
  final Wallet? usdWallet;
  final int rateScaled;
  final String displayMode;

  @override
  Widget build(BuildContext context) {
    final target = targetCurrencyFor(displayMode);
    final total = totalBalance(
      cdfBalance: cdfWallet?.balance ?? 0,
      usdBalance: usdWallet?.balance ?? 0,
      currentRateScaled: rateScaled,
      target: target,
    );
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total balance', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              formatMinorAmount(total, target),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Converted at the current rate',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

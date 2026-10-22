import 'package:money_manager/data/models/transaction.dart';

/// Integer division rounding half away from zero (denominator > 0).
int divRoundHalfAway(int numerator, int denominator) {
  final n = numerator.abs();
  final q = (n * 2 + denominator) ~/ (2 * denominator);
  return numerator < 0 ? -q : q;
}

/// Rate is CDF per 1 USD x100 (2800.50 -> 280050).
int usdCentsToCdf(int cents, int rateScaled) =>
    divRoundHalfAway(cents * rateScaled, 10000);

int cdfToUsdCents(int francs, int rateScaled) =>
    divRoundHalfAway(francs * 10000, rateScaled);

/// Converts a minor-unit amount between 'CDF' and 'USD'.
int convertMinor({
  required int amount,
  required String from,
  required String to,
  required int rateScaled,
}) {
  if (from == to) return amount;
  if (from == 'USD' && to == 'CDF') return usdCentsToCdf(amount, rateScaled);
  if (from == 'CDF' && to == 'USD') return cdfToUsdCents(amount, rateScaled);
  throw ArgumentError('Unsupported currencies: $from -> $to');
}

/// displayMode: cdf | usd | combined. Combined totals are shown in CDF.
String targetCurrencyFor(String displayMode) =>
    displayMode == 'usd' ? 'USD' : 'CDF';

/// Total of both wallets in [target] using the CURRENT rate.
int totalBalance({
  required int cdfBalance,
  required int usdBalance,
  required int currentRateScaled,
  required String target,
}) {
  final cdf = convertMinor(
    amount: cdfBalance,
    from: 'CDF',
    to: target,
    rateScaled: currentRateScaled,
  );
  final usd = convertMinor(
    amount: usdBalance,
    from: 'USD',
    to: target,
    rateScaled: currentRateScaled,
  );
  return cdf + usd;
}

class MonthSummary {
  const MonthSummary({
    required this.income,
    required this.expense,
    required this.currency,
  });

  final int income;
  final int expense;
  final String currency;
  int get net => income - expense;
}

/// Sums transactions (already filtered to the month, conversions excluded),
/// converting each one with ITS OWN rateAtEntry.
MonthSummary monthSummary({
  required List<Transaction> transactions,
  required String target,
}) {
  var income = 0;
  var expense = 0;
  for (final t in transactions) {
    final value = convertMinor(
      amount: t.amount,
      from: t.currency,
      to: target,
      rateScaled: t.rateAtEntry,
    );
    if (t.type == 'income') {
      income += value;
    } else if (t.type == 'expense') {
      expense += value;
    }
  }
  return MonthSummary(income: income, expense: expense, currency: target);
}

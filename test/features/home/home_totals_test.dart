import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/home/application/home_totals.dart';

Transaction _t(String type, int amount, String currency, int rate) =>
    Transaction(
      id: '$type$amount$currency$rate',
      amount: amount,
      currency: currency,
      type: type,
      categoryId: 'c',
      date: DateTime(2026, 10, 5),
      rateAtEntry: rate,
      createdAt: DateTime(2026, 10, 5),
    );

void main() {
  test('1000.00 USD at 2800.50 is 2,800,500 CDF', () {
    expect(usdCentsToCdf(100000, 280050), 2800500);
  });

  test('CDF to USD cents rounds half away from zero', () {
    expect(cdfToUsdCents(2800500, 280050), 100000);
    expect(cdfToUsdCents(1400, 280050), 50); // 0.4999 -> 50 cents
    expect(divRoundHalfAway(-5, 2), -3);
    expect(divRoundHalfAway(5, 2), 3);
  });

  test('same currency is not converted', () {
    expect(
      convertMinor(amount: 1234, from: 'CDF', to: 'CDF', rateScaled: 1),
      1234,
    );
  });

  test('total balance uses the current rate', () {
    expect(
      totalBalance(
        cdfBalance: 500000,
        usdBalance: 100000,
        currentRateScaled: 280050,
        target: 'CDF',
      ),
      3300500,
    );
  });

  test('month summary converts each transaction with its own rateAtEntry', () {
    final s = monthSummary(
      target: 'CDF',
      transactions: [
        _t('income', 100000, 'USD', 280000), // 2,800,000 CDF
        _t('income', 100000, 'USD', 290000), // 2,900,000 CDF
        _t('expense', 100000, 'CDF', 1), // 100,000 CDF, no conversion
      ],
    );
    expect(s.income, 5700000);
    expect(s.expense, 100000);
    expect(s.net, 5600000);
  });

  test('changing the current rate does not change the month summary', () {
    final txs = [_t('expense', 50000, 'USD', 280000)];
    final a = monthSummary(transactions: txs, target: 'CDF');
    final b = monthSummary(transactions: txs, target: 'CDF');
    expect(a.expense, b.expense);
    expect(a.expense, 1400000);
  });

  test('display mode picks the target currency', () {
    expect(targetCurrencyFor('usd'), 'USD');
    expect(targetCurrencyFor('cdf'), 'CDF');
    expect(targetCurrencyFor('combined'), 'CDF');
  });
}

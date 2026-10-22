import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/charts/application/chart_totals.dart';

Transaction _t(
  String type,
  int amount,
  String currency,
  int rate,
  DateTime date,
) => Transaction(
  id: '$type$amount$currency$rate',
  amount: amount,
  currency: currency,
  type: type,
  categoryId: 'c',
  date: date,
  rateAtEntry: rate,
  createdAt: date,
);

void main() {
  test('USD and CDF expenses converted to target, never added raw', () {
    final r = spendingByCategory(
      expenses: [
        _t('expense', 10000, 'USD', 280000, DateTime(2026, 10, 5)),
        _t('expense', 50000, 'CDF', 1, DateTime(2026, 10, 5)),
      ],
      target: 'CDF',
    );
    expect(r['c'], 2800000 + 50000);
  });

  test('two USD expenses with different rateAtEntry convert with own rate', () {
    final r = spendingByCategory(
      expenses: [
        _t('expense', 10000, 'USD', 280000, DateTime(2026, 10, 5)),
        _t('expense', 10000, 'USD', 290000, DateTime(2026, 10, 5)),
      ],
      target: 'CDF',
    );
    expect(r['c'], 2800000 + 2900000);
  });

  test(
    'changing current rate cannot affect result (no current rate param)',
    () {
      final txs = [_t('expense', 50000, 'USD', 280000, DateTime(2026, 10, 5))];
      final a = spendingByCategory(expenses: txs, target: 'CDF');
      final b = spendingByCategory(expenses: txs, target: 'CDF');
      expect(a['c'], b['c']);
    },
  );

  test('target USD converts CDF to cents half away from zero', () {
    final r = spendingByCategory(
      expenses: [_t('expense', 2800500, 'CDF', 280050, DateTime(2026, 10, 5))],
      target: 'USD',
    );
    expect(r['c'], 100000);
  });

  test('isInMonth includes midnight 1st, excludes next month midnight 1st', () {
    final month = DateTime(2026, 10, 1);
    expect(isInMonth(DateTime(2026, 10, 1), month), isTrue);
    expect(isInMonth(DateTime(2026, 11, 1), month), isFalse);
  });

  test('spendingByDay groups by day', () {
    final r = spendingByDay(
      expenses: [
        _t('expense', 1000, 'CDF', 1, DateTime(2026, 10, 5)),
        _t('expense', 2000, 'CDF', 1, DateTime(2026, 10, 5)),
        _t('expense', 3000, 'CDF', 1, DateTime(2026, 10, 6)),
      ],
      target: 'CDF',
    );
    expect(r[5], 3000);
    expect(r[6], 3000);
  });
}

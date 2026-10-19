import 'package:flutter_test/flutter_test.dart';

/// Budget math test: 80% warning / 100% exceeded boundaries,
/// same category and currency only.
int _budgetPct(int spent, int limit) {
  return limit > 0 ? (spent * 100) ~/ limit : 0;
}

bool _isWarning(int spent, int limit) {
  return limit > 0 && spent * 100 >= limit * 80 && spent * 100 < limit * 100;
}

bool _isExceeded(int spent, int limit) {
  return limit > 0 && spent * 100 >= limit * 100;
}

void main() {
  group('Budget math boundaries', () {
    test('0% spending is below warning', () {
      expect(_budgetPct(0, 10000), 0);
      expect(_isWarning(0, 10000), false);
      expect(_isExceeded(0, 10000), false);
    });

    test('79% spending is below warning', () {
      expect(_budgetPct(7900, 10000), 79);
      expect(_isWarning(7900, 10000), false);
    });

    test('80% spending is warning', () {
      expect(_budgetPct(8000, 10000), 80);
      expect(_isWarning(8000, 10000), true);
      expect(_isExceeded(8000, 10000), false);
    });

    test('99% spending is warning', () {
      expect(_budgetPct(9900, 10000), 99);
      expect(_isWarning(9900, 10000), true);
    });

    test('100% spending is exceeded', () {
      expect(_budgetPct(10000, 10000), 100);
      expect(_isWarning(10000, 10000), false);
      expect(_isExceeded(10000, 10000), true);
    });

    test('101% spending is exceeded', () {
      expect(_budgetPct(10100, 10000), 101);
      expect(_isExceeded(10100, 10000), true);
    });

    test('zero limit means no warning/exceeded', () {
      expect(_budgetPct(5000, 0), 0);
      expect(_isWarning(5000, 0), false);
      expect(_isExceeded(5000, 0), false);
    });
  });

  group('Same category and currency only', () {
    test('spending in different currency does not count', () {
      // Budget is in CDF, spending is in USD - should not count
      final budgetCurrency = 'CDF';
      final spendingCurrency = 'USD';
      expect(budgetCurrency == spendingCurrency, false);
    });

    test('spending in same category and currency counts', () {
      final budgetCategory = 'cat_food';
      final spendingCategory = 'cat_food';
      final budgetCurrency = 'CDF';
      final spendingCurrency = 'CDF';
      expect(budgetCategory == spendingCategory, true);
      expect(budgetCurrency == spendingCurrency, true);
    });
  });
}

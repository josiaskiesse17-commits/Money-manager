import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/balance_delta.dart';
import 'package:money_manager/data/models/transaction.dart';

void main() {
  group('balanceDeltas', () {
    final now = DateTime(2026, 1, 15, 10, 30, 0);

    Transaction incomeTxn({
      String id = 'txn',
      int amount = 100,
      String currency = 'USD',
      String categoryId = 'cat',
    }) => Transaction(
      id: id,
      amount: amount,
      currency: currency,
      type: 'income',
      categoryId: categoryId,
      date: now,
      rateAtEntry: 280050,
      createdAt: now,
    );

    Transaction expenseTxn({
      String id = 'txn',
      int amount = 100,
      String currency = 'USD',
      String categoryId = 'cat',
    }) => Transaction(
      id: id,
      amount: amount,
      currency: currency,
      type: 'expense',
      categoryId: categoryId,
      date: now,
      rateAtEntry: 280050,
      createdAt: now,
    );

    test('add income increases balance', () {
      expect(balanceDeltas(null, incomeTxn()), {'USD': 100});
    });

    test('add expense decreases balance', () {
      expect(balanceDeltas(null, expenseTxn()), {'USD': -100});
    });

    test('delete income decreases balance', () {
      expect(balanceDeltas(incomeTxn(), null), {'USD': -100});
    });

    test('delete expense increases balance', () {
      expect(balanceDeltas(expenseTxn(), null), {'USD': 100});
    });

    test('edit income amount increases delta', () {
      expect(balanceDeltas(incomeTxn(amount: 100), incomeTxn(amount: 150)), {
        'USD': 50,
      });
    });

    test('edit expense amount decreases delta', () {
      expect(balanceDeltas(expenseTxn(amount: 100), expenseTxn(amount: 150)), {
        'USD': -50,
      });
    });

    test('edit income to expense decreases balance', () {
      expect(balanceDeltas(incomeTxn(amount: 100), expenseTxn(amount: 100)), {
        'USD': -200,
      });
    });

    test('edit expense to income increases balance', () {
      expect(balanceDeltas(expenseTxn(amount: 100), incomeTxn(amount: 100)), {
        'USD': 200,
      });
    });

    test('edit currency change splits delta', () {
      expect(
        balanceDeltas(
          incomeTxn(amount: 100, currency: 'USD'),
          incomeTxn(amount: 100, currency: 'CDF'),
        ),
        {'USD': -100, 'CDF': 100},
      );
    });

    test('edit amount and currency together', () {
      expect(
        balanceDeltas(
          expenseTxn(amount: 100, currency: 'USD'),
          incomeTxn(amount: 200, currency: 'CDF'),
        ),
        {'USD': 100, 'CDF': 200},
      );
    });

    test('same transaction returns empty', () {
      expect(balanceDeltas(incomeTxn(amount: 100), incomeTxn(amount: 100)), {});
    });

    test('both null returns empty', () {
      expect(balanceDeltas(null, null), {});
    });
  });
}

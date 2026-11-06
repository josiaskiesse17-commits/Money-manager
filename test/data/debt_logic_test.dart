import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/debt_logic.dart';

void main() {
  group('walletDeltaForNewDebt', () {
    test('owe returns positive principal', () {
      expect(walletDeltaForNewDebt('owe', 50000), 50000);
    });
    test('owed returns negative principal', () {
      expect(walletDeltaForNewDebt('owed', 50000), -50000);
    });
    test('unknown direction throws', () {
      expect(() => walletDeltaForNewDebt('invalid', 100), throwsArgumentError);
    });
  });

  group('walletDeltaForPayment', () {
    test('owe returns negative amount', () {
      expect(walletDeltaForPayment('owe', 5000), -5000);
    });
    test('owed returns positive amount', () {
      expect(walletDeltaForPayment('owed', 5000), 5000);
    });
    test('unknown direction throws', () {
      expect(() => walletDeltaForPayment('invalid', 100), throwsArgumentError);
    });
  });

  group('remainingAfterPayment', () {
    test('subtracts amount from remaining', () {
      expect(remainingAfterPayment(30000, 5000), 25000);
    });
    test('clamps at zero for full payment', () {
      expect(remainingAfterPayment(5000, 5000), 0);
    });
    test('does not go below zero for overpayment', () {
      expect(remainingAfterPayment(3000, 5000), 0);
    });
  });

  group('remainingAfterPaymentDeleted', () {
    test('adds amount back to remaining', () {
      expect(remainingAfterPaymentDeleted(25000, 5000, 50000), 30000);
    });
    test('clamps at principal', () {
      expect(remainingAfterPaymentDeleted(48000, 5000, 50000), 50000);
    });
  });

  group('validatePayment', () {
    test('valid when amount <= remaining and > 0', () {
      expect(validatePayment(10000, 5000).isValid, true);
      expect(validatePayment(10000, 10000).isValid, true);
    });
    test('invalid when amount is zero', () {
      final result = validatePayment(10000, 0);
      expect(result.isValid, false);
      expect(result.error, isNotNull);
    });
    test('invalid when amount is negative', () {
      final result = validatePayment(10000, -100);
      expect(result.isValid, false);
      expect(result.error, isNotNull);
    });
    test('invalid when amount exceeds remaining', () {
      final result = validatePayment(5000, 5001);
      expect(result.isValid, false);
      expect(result.error, isNotNull);
    });
  });

  group('isSettled', () {
    test('true when remaining is zero', () {
      final debt = Debt(
        id: 'd1', name: 'x', direction: 'owe', currency: 'USD',
        principal: 10000, remaining: 0, archived: false, createdAt: DateTime.now(),
      );
      expect(isSettled(debt), true);
    });
    test('false when remaining is greater than zero', () {
      final debt = Debt(
        id: 'd1', name: 'x', direction: 'owe', currency: 'USD',
        principal: 10000, remaining: 1000, archived: false, createdAt: DateTime.now(),
      );
      expect(isSettled(debt), false);
    });
  });
}

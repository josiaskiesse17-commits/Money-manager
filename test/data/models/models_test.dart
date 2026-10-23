import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/conversion.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/models/wallet.dart';

void main() {
  group('Setting round trip', () {
    test('toMap then fromMap preserves all fields', () {
      final original = Setting(
        docId: 'main',
        usdToCdfRate: 280050,
        theme: 'dark',
        displayMode: 'combined',
        onboarded: true,
      );
      final map = original.toMap();
      final restored = Setting.fromMap('main', map);
      expect(restored, original);
    });
  });

  group('Wallet round trip', () {
    test('toMap then fromMap preserves all fields', () {
      final original = Wallet(
        currency: 'CDF',
        openingBalance: 35000,
        balance: 42000,
      );
      final map = original.toMap();
      final restored = Wallet.fromMap('CDF', map);
      expect(restored, original);
    });
  });

  group('Category round trip', () {
    test('toMap then fromMap preserves all fields', () {
      final original = Category(
        id: 'cat_food',
        name: 'Food',
        icon: 'restaurant',
        color: 0xFFFF0000,
        type: 'expense',
        archived: false,
      );
      final map = original.toMap();
      final restored = Category.fromMap('cat_food', map);
      expect(restored, original);
    });

    test('isIncome and isExpense getters', () {
      final income = Category(
        id: 'c1',
        name: 'Salary',
        icon: 'work',
        color: 0xFF000000,
        type: 'income',
        archived: false,
      );
      final expense = Category(
        id: 'c2',
        name: 'Food',
        icon: 'restaurant',
        color: 0xFF000000,
        type: 'expense',
        archived: false,
      );
      expect(income.isIncome, true);
      expect(income.isExpense, false);
      expect(expense.isIncome, false);
      expect(expense.isExpense, true);
    });
  });

  group('Transaction round trip', () {
    final now = DateTime(2026, 1, 15, 10, 30, 0);

    test('toMap then fromMap preserves all fields', () {
      final original = Transaction(
        id: 'txn_1',
        amount: 123450,
        currency: 'USD',
        type: 'expense',
        categoryId: 'cat_food',
        date: now,
        note: 'Groceries',
        rateAtEntry: 280050,
        createdAt: now,
        updatedAt: now,
      );
      final map = original.toMap();
      final restored = Transaction.fromMap('txn_1', map);
      expect(restored, original);
    });

    test('toMap then fromMap with null note and updatedAt', () {
      final original = Transaction(
        id: 'txn_2',
        amount: 35000,
        currency: 'CDF',
        type: 'income',
        categoryId: 'cat_salary',
        date: now,
        note: null,
        rateAtEntry: 280050,
        createdAt: now,
        updatedAt: null,
      );
      final map = original.toMap();
      final restored = Transaction.fromMap('txn_2', map);
      // toMap serializes null note as empty string (Firestore rules require string).
      // fromMap converts empty string back to null (no note in UI).
      expect(restored.note, isNull);
      expect(restored.amount, original.amount);
      expect(restored.currency, original.currency);
      expect(restored.type, original.type);
      expect(restored.categoryId, original.categoryId);
      expect(restored.rateAtEntry, original.rateAtEntry);
    });
  });

  group('Conversion round trip', () {
    final now = DateTime(2026, 1, 15, 11, 0, 0);

    test('toMap then fromMap preserves all fields', () {
      final original = Conversion(
        id: 'conv_1',
        fromCurrency: 'USD',
        toCurrency: 'CDF',
        fromAmount: 10000,
        toAmount: 280050,
        rate: 280050,
        date: now,
      );
      final map = original.toMap();
      final restored = Conversion.fromMap('conv_1', map);
      expect(restored, original);
    });
  });

  group('Budget round trip', () {
    test('toMap then fromMap preserves all fields', () {
      final original = Budget(
        categoryId: 'cat_food',
        currency: 'CDF',
        monthlyLimit: 175000,
      );
      final map = original.toMap();
      final restored = Budget.fromMap('cat_food', map);
      expect(restored, original);
    });
  });
}

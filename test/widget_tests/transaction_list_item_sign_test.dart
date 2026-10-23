import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/transaction.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  final foodCategory = Category(
    id: 'cat_food',
    name: 'Food',
    icon: 'restaurant',
    color: 0xFFFF5722,
    type: 'expense',
    archived: false,
  );

  final salaryCategory = Category(
    id: 'cat_salary',
    name: 'Salary',
    icon: 'work',
    color: 0xFF4CAF50,
    type: 'income',
    archived: false,
  );

  testWidgets('Expense transaction shows minus sign in red', (tester) async {
    final expense = Transaction(
      id: 'txn1',
      amount: 123450,
      currency: 'USD',
      type: 'expense',
      categoryId: 'cat_food',
      date: DateTime(2024, 6, 15, 14, 30),
      note: 'Groceries',
      rateAtEntry: 280050,
      createdAt: DateTime(2024, 6, 15, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: TransactionListItem(
            transaction: expense,
            category: foodCategory,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    final textFinder = find.text('-\$1,234.50');
    expect(textFinder, findsOneWidget);

    final text = tester.widget<Text>(textFinder);
    final moneyColors = AppTheme.light().extension<MoneyColors>();
    expect(text.style?.color, moneyColors?.expense);
  });

  testWidgets('Income transaction shows plus sign in green', (tester) async {
    final income = Transaction(
      id: 'txn2',
      amount: 500000,
      currency: 'USD',
      type: 'income',
      categoryId: 'cat_salary',
      date: DateTime(2024, 6, 15, 9, 0),
      note: 'Paycheck',
      rateAtEntry: 280050,
      createdAt: DateTime(2024, 6, 15, 9, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: TransactionListItem(
            transaction: income,
            category: salaryCategory,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    final textFinder = find.text('+\$5,000.00');
    expect(textFinder, findsOneWidget);

    final text = tester.widget<Text>(textFinder);
    final moneyColors = AppTheme.light().extension<MoneyColors>();
    expect(text.style?.color, moneyColors?.income);
  });
}

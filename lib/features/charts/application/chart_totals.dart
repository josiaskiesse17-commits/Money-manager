import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/home/application/home_totals.dart';

/// True when [date] is inside the month of [month] (start inclusive).
bool isInMonth(DateTime date, DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  return !date.isBefore(start) && date.isBefore(end);
}

/// Spending per category in [target], converting each transaction with
/// its OWN rateAtEntry (never the current rate).
Map<String, int> spendingByCategory({
  required List<Transaction> expenses,
  required String target,
}) {
  final result = <String, int>{};
  for (final t in expenses) {
    final value = convertMinor(
      amount: t.amount,
      from: t.currency,
      to: target,
      rateScaled: t.rateAtEntry,
    );
    result[t.categoryId] = (result[t.categoryId] ?? 0) + value;
  }
  return result;
}

/// Spending per day of month in [target], using each transaction's own rate.
Map<int, int> spendingByDay({
  required List<Transaction> expenses,
  required String target,
}) {
  final result = <int, int>{};
  for (final t in expenses) {
    final value = convertMinor(
      amount: t.amount,
      from: t.currency,
      to: target,
      rateScaled: t.rateAtEntry,
    );
    result[t.date.day] = (result[t.date.day] ?? 0) + value;
  }
  return result;
}

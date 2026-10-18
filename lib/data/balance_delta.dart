import 'package:money_manager/data/models/transaction.dart';

/// Computes the balance change caused by adding, deleting, or editing a
/// transaction. Returns a map of currency -> delta (minor units).
/// Positive delta adds to the wallet balance, negative subtracts.
///
/// - Add (before null):   +after.amount if income, -after.amount if expense
/// - Delete (after null): -before.amount if income, +before.amount if expense
/// - Edit (both):         remove old + add new; handles type or currency changes
Map<String, int> balanceDeltas(Transaction? before, Transaction? after) {
  final deltas = <String, int>{};

  void apply(String currency, int amount, bool isIncome, bool isAdding) {
    // Adding: income +, expense -
    // Removing: income -, expense +
    final sign = isAdding ? (isIncome ? 1 : -1) : (isIncome ? -1 : 1);
    deltas[currency] = (deltas[currency] ?? 0) + sign * amount;
  }

  if (before != null) {
    apply(before.currency, before.amount, before.type == 'income', false);
  }
  if (after != null) {
    apply(after.currency, after.amount, after.type == 'income', true);
  }

  deltas.removeWhere((_, v) => v == 0);
  return deltas;
}

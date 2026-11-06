// Pure logic for debts and debt payments. No Flutter or Firebase imports.

import 'package:money_manager/data/models/debt.dart';

/// Signed wallet delta when a new debt is created.
/// 'owe' (I borrowed) = wallet +principal; 'owed' (I lent) = wallet -principal.
int walletDeltaForNewDebt(String direction, int principal) {
  switch (direction) {
    case 'owe':
      return principal;
    case 'owed':
      return -principal;
    default:
      throw ArgumentError('Unknown debt direction: $direction');
  }
}

/// Signed wallet delta when a payment is recorded.
/// 'owe' = wallet -amount; 'owed' = wallet +amount.
int walletDeltaForPayment(String direction, int amount) {
  switch (direction) {
    case 'owe':
      return -amount;
    case 'owed':
      return amount;
    default:
      throw ArgumentError('Unknown debt direction: $direction');
  }
}

/// Remaining after recording a payment of [amount] against [remaining].
/// Never goes below 0.
int remainingAfterPayment(int remaining, int amount) {
  final result = remaining - amount;
  return result < 0 ? 0 : result;
}

/// Remaining after a payment of [amount] is deleted.
/// Never goes above [principal].
int remainingAfterPaymentDeleted(int remaining, int amount, int principal) {
  final result = remaining + amount;
  return result > principal ? principal : result;
}

/// Result of validating a payment amount against a debt's [remaining].
class PaymentValidationResult {
  final bool isValid;
  final String? error;

  const PaymentValidationResult({required this.isValid, this.error});
}

/// Validates a payment amount: invalid when amount <= 0 or amount > remaining.
PaymentValidationResult validatePayment(int remaining, int amount) {
  if (amount <= 0) {
    return const PaymentValidationResult(
      isValid: false,
      error: 'Payment amount must be greater than zero.',
    );
  }
  if (amount > remaining) {
    return const PaymentValidationResult(
      isValid: false,
      error: 'Payment cannot exceed the remaining balance.',
    );
  }
  return const PaymentValidationResult(isValid: true);
}

/// Whether a debt is fully paid off.
bool isSettled(Debt debt) => debt.remaining == 0;

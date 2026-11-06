import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/data/debt_logic.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/models/debt_payment.dart';
import 'package:money_manager/data/repositories/debt_repository.dart';

class DebtStateNotifier extends StateNotifier<AsyncValue<List<Debt>>> {  DebtStateNotifier(this._repo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final DebtRepository _repo;
  final String _uid;

  StreamSubscription? _debtsSubscription;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    try {
      _debtsSubscription = _repo
          .watchDebts(_uid)
          .listen(
            (debts) {
              state = AsyncValue.data(debts);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addDebt(Debt debt) async {
    await _repo.addDebt(_uid, debt);
  }

  /// Records a payment after validating it against the debt's remaining balance.
  Future<void> addPayment(Debt debt, DebtPayment payment) async {
    final validation = validatePayment(debt.remaining, payment.amount);

    if (!validation.isValid) {
      reportError(
        validation.error ?? 'Invalid payment.',
        userMessage: validation.error,
      );
      throw StateError(validation.error ?? 'Invalid payment.');
    }

    await _repo.addPayment(_uid, debt, payment);
  }

  Future<void> deletePayment(Debt debt, DebtPayment payment) async {
    await _repo.deletePayment(_uid, debt, payment);
  }

  Future<void> archiveDebt(String debtId, bool archived) async {
    await _repo.archiveDebt(_uid, debtId, archived);
  }

  Future<void> updateDebt(Debt debt) async {
    await _repo.updateDebt(_uid, debt);
  }

  @override
  void dispose() {
    _debtsSubscription?.cancel();
    super.dispose();
  }
}

/// Debts for the current user, keyed by uid.
final debtProvider =
    StateNotifierProvider.family<
      DebtStateNotifier,
      AsyncValue<List<Debt>>,
      String
    >(
      (ref, uid) =>
          DebtStateNotifier(ref.read(debtRepositoryProvider), uid),
    );

/// Payments for a single debt, keyed by debtId. The uid comes from the
/// signed-in user so the stream is scoped to the current user's debts.
final debtPaymentsProvider =
    StreamProvider.family<List<DebtPayment>, String>((ref, debtId) {
  final user = ref.watch(authProvider);
  final uid = user?.uid ?? '';
  return ref.read(debtRepositoryProvider).watchPayments(uid, debtId);
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/repositories/transaction_repository.dart';

class TransactionStateNotifier
    extends StateNotifier<AsyncValue<List<Transaction>>> {
  TransactionStateNotifier(this._txnRepo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final TransactionRepository _txnRepo;
  final String _uid;

  StreamSubscription? _subscription;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    try {
      _subscription = _txnRepo
          .watchTransactions(_uid)
          .listen(
            (txns) {
              state = AsyncValue.data(txns);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(Transaction txn) async {
    await _txnRepo.addTransaction(_uid, txn);
  }

  Future<void> update(Transaction before, Transaction after) async {
    await _txnRepo.updateTransaction(_uid, before, after);
  }

  Future<void> delete(Transaction txn) async {
    await _txnRepo.deleteTransaction(_uid, txn);
  }

  Future<void> restore(Transaction txn) async {
    await _txnRepo.restoreTransaction(_uid, txn);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final transactionProvider =
    StateNotifierProvider.family<
      TransactionStateNotifier,
      AsyncValue<List<Transaction>>,
      String
    >(
      (ref, uid) => TransactionStateNotifier(
        ref.read(transactionRepositoryProvider),
        uid,
      ),
    );

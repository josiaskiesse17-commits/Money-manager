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
  Timer? _timeoutTimer;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (state is AsyncLoading) {
        state = AsyncValue.error(
          'Transactions loading timed out. Please check your connection.',
          StackTrace.current,
        );
      }
    });

    try {
      _subscription = _txnRepo
          .watchTransactions(_uid)
          .listen(
            (txns) {
              _timeoutTimer?.cancel();
              state = AsyncValue.data(txns);
            },
            onError: (error, stackTrace) {
              _timeoutTimer?.cancel();
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      _timeoutTimer?.cancel();
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

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
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

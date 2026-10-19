import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/data/repositories/budget_repository.dart';

class BudgetStateNotifier extends StateNotifier<AsyncValue<List<Budget>>> {
  BudgetStateNotifier(this._repo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final BudgetRepository _repo;
  final String _uid;

  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (state is AsyncLoading) {
        state = AsyncValue.error(
          'Budgets loading timed out. Please check your connection.',
          StackTrace.current,
        );
      }
    });

    try {
      _subscription = _repo
          .watchBudgets(_uid)
          .listen(
            (budgets) {
              _timeoutTimer?.cancel();
              state = AsyncValue.data(budgets);
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

  Future<void> save(Budget budget) async {
    await _repo.saveBudget(_uid, budget);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}

final budgetProvider =
    StateNotifierProvider.family<
      BudgetStateNotifier,
      AsyncValue<List<Budget>>,
      String
    >(
      (ref, uid) =>
          BudgetStateNotifier(ref.read(budgetRepositoryProvider), uid),
    );

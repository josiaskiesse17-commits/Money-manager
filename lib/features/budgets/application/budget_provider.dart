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

  Future<void> _load() async {
    state = const AsyncValue.loading();

    try {
      _subscription = _repo
          .watchBudgets(_uid)
          .listen(
            (budgets) {
              state = AsyncValue.data(budgets);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(Budget budget) async {
    await _repo.saveBudget(_uid, budget);
  }

  @override
  void dispose() {
    _subscription?.cancel();
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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/repositories/category_repository.dart';

class CategoryStateNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  CategoryStateNotifier(this._repo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final CategoryRepository _repo;
  final String _uid;

  StreamSubscription? _subscription;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    try {
      _subscription = _repo
          .watchCategories(_uid)
          .listen(
            (categories) {
              state = AsyncValue.data(categories);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(Category category) async {
    await _repo.saveCategory(_uid, category);
  }

  Future<void> archive(String id, bool archived) async {
    await _repo.archiveCategory(_uid, id, archived);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final categoryProvider =
    StateNotifierProvider.family<
      CategoryStateNotifier,
      AsyncValue<List<Category>>,
      String
    >(
      (ref, uid) =>
          CategoryStateNotifier(ref.read(categoryRepositoryProvider), uid),
    );

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/conversion.dart';
import 'package:money_manager/data/repositories/conversion_repository.dart';

class ConversionStateNotifier
    extends StateNotifier<AsyncValue<List<Conversion>>> {
  ConversionStateNotifier(this._repo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final ConversionRepository _repo;
  final String _uid;

  StreamSubscription? _subscription;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    try {
      _subscription = _repo
          .watchConversions(_uid)
          .listen(
            (conversions) {
              state = AsyncValue.data(conversions);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(Conversion conversion) async {
    await _repo.addConversion(_uid, conversion);
  }

  Future<void> delete(Conversion conversion) async {
    await _repo.deleteConversion(_uid, conversion);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final conversionProvider =
    StateNotifierProvider.family<
      ConversionStateNotifier,
      AsyncValue<List<Conversion>>,
      String
    >(
      (ref, uid) =>
          ConversionStateNotifier(ref.read(conversionRepositoryProvider), uid),
    );

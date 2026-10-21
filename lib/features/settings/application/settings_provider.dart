import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/repositories/settings_repository.dart';

class SettingsStateNotifier extends StateNotifier<AsyncValue<Setting?>> {
  SettingsStateNotifier(this._repo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final SettingsRepository _repo;
  final String _uid;

  StreamSubscription<Setting?>? _subscription;

  Future<void> _load() async {
    try {
      _subscription = _repo
          .watchSettings(_uid)
          .listen(
            (setting) {
              state = AsyncValue.data(setting);
            },
            onError: (Object error, StackTrace stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> save(Setting setting) async {
    final previousState = state;

    try {
      await _repo.saveSettings(_uid, setting);

      // Update immediately so the UI remains responsive.
      // The Firestore stream will continue to synchronize remote changes.
      state = AsyncValue.data(setting);
    } catch (error, stackTrace) {
      // Preserve the previous settings instead of leaving the screen
      // permanently loading or replacing valid data with an error screen.
      final previousSetting = previousState.valueOrNull;

      if (previousSetting != null) {
        state = AsyncValue.data(previousSetting);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }

      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final settingsProvider =
    StateNotifierProvider.family<
      SettingsStateNotifier,
      AsyncValue<Setting?>,
      String
    >((ref, uid) {
      return SettingsStateNotifier(ref.read(settingsRepositoryProvider), uid);
    });

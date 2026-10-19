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
  Timer? _timeoutTimer;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    // Timeout fallback: if settings don't load within 10s, show error with retry
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (state is AsyncLoading) {
        state = AsyncValue.error(
          'Settings loading timed out. Please check your connection.',
          StackTrace.current,
        );
      }
    });

    try {
      _subscription = _repo.watchSettings(_uid).listen((setting) {
        _timeoutTimer?.cancel();
        if (setting == null) {
          state = const AsyncValue.data(null); // Needs onboarding
        } else {
          state = AsyncValue.data(setting);
        }
      });
    } catch (e, st) {
      _timeoutTimer?.cancel();
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(Setting setting) async {
    state = const AsyncValue.loading();
    try {
      await _repo.saveSettings(_uid, setting);
      // Don't set state here — the .watch() stream will emit the saved doc
      // and update state reactively. This avoids a race where local state
      // diverges from Firestore.
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}

final settingsProvider =
    StateNotifierProvider.family<
      SettingsStateNotifier,
      AsyncValue<Setting?>,
      String
    >(
      (ref, uid) =>
          SettingsStateNotifier(ref.read(settingsRepositoryProvider), uid),
    );

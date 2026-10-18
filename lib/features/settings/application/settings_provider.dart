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

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final snap = await _repo.settingsDoc(_uid).get();
      if (snap.exists) {
        state = AsyncValue.data(Setting.fromDocument(snap));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(Setting setting) async {
    state = const AsyncValue.loading();
    try {
      await _repo.saveSettings(_uid, setting);
      state = AsyncValue.data(setting);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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

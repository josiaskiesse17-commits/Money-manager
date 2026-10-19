import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';

class WalletStateNotifier extends StateNotifier<AsyncValue<List<Wallet>>> {
  WalletStateNotifier(this._repo, this._uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final WalletRepository _repo;
  final String _uid;

  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  Future<void> _load() async {
    state = const AsyncValue.loading();

    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (state is AsyncLoading) {
        state = AsyncValue.error(
          'Wallets loading timed out. Please check your connection.',
          StackTrace.current,
        );
      }
    });

    try {
      _subscription = _repo
          .watchWallets(_uid)
          .listen(
            (wallets) {
              _timeoutTimer?.cancel();
              state = AsyncValue.data(wallets);
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

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}

final walletProvider =
    StateNotifierProvider.family<
      WalletStateNotifier,
      AsyncValue<List<Wallet>>,
      String
    >(
      (ref, uid) =>
          WalletStateNotifier(ref.read(walletRepositoryProvider), uid),
    );

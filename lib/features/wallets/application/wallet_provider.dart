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

  Future<void> _load() async {
    state = const AsyncValue.loading();

    try {
      _subscription = _repo
          .watchWallets(_uid)
          .listen(
            (wallets) {
              state = AsyncValue.data(wallets);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
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

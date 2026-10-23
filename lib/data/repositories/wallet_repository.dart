import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/wallet.dart';

class WalletRepository {
  WalletRepository(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference walletDoc(String uid, String currency) => _firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc(currency);

  Stream<Wallet?> watchWallet(String uid, String currency) {
    return walletDoc(uid, currency).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Wallet.fromDocument(doc);
    });
  }

  Stream<List<Wallet>> watchWallets(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('wallets')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Wallet.fromDocument(d)).toList());
  }

  Future<void> updateBalance(String uid, String currency, int delta) {
    return walletDoc(
      uid,
      currency,
    ).update({'balance': FieldValue.increment(delta)}).catchError((e) {
      reportError(e);
      throw e;
    });
  }

  /// Adjusts a wallet's balance by [diff] (newBalance - currentBalance) in a
  /// single WriteBatch, incrementing both balance and openingBalance so
  /// history stays consistent. Fire-and-forget: errors are reported via
  /// [reportError] and rethrown so the caller can surface a banner.
  Future<void> adjustBalance(String uid, String currency, int diff) async {
    final batch = _firestore.batch();
    final doc = walletDoc(uid, currency);
    batch.set(doc, {
      'balance': FieldValue.increment(diff),
      'openingBalance': FieldValue.increment(diff),
    }, SetOptions(merge: true));
    try {
      await batch.commit();
    } on Object catch (e) {
      reportError(e);
      rethrow;
    }
  }

  /// Ensures both wallet documents (CDF and USD) exist with `currency`,
  /// `openingBalance` and `balance` fields. Missing fields default to 0.
  /// Existing `balance`/`openingBalance` values are never overwritten: uses
  /// `FieldValue.increment(0)` so the fields are created only when absent,
  /// and left untouched when present. Fire-and-forget: errors are reported
  /// via [reportError] and swallowed so a missing wallet can never block
  /// the user.
  Future<void> ensureWalletsExist(String uid) {
    final batch = _firestore.batch();
    for (final currency in <String>['CDF', 'USD']) {
      batch.set(walletDoc(uid, currency), {
        'currency': currency,
        'balance': FieldValue.increment(0),
        'openingBalance': FieldValue.increment(0),
      }, SetOptions(merge: true));
    }
    return batch.commit().catchError((e) {
      reportError(e);
    });
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.read(firestoreProvider));
});

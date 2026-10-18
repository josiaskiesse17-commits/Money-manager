import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/balance_delta.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference _txns(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');
  DocumentReference _wallet(String uid, String currency) => _firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc(currency);

  Stream<List<Transaction>> watchTransactions(String uid) {
    return _txns(uid).snapshots().map((snap) {
      return snap.docs.map((d) => Transaction.fromDocument(d)).toList();
    });
  }

  /// Writes transaction + wallet balance updates in a single WriteBatch.
  /// Fire-and-forget: offline futures only finish when the server answers.
  Future<void> addTransaction(String uid, Transaction txn) {
    final batch = _firestore.batch();
    final txnRef = _txns(uid).doc(txn.id);
    batch.set(txnRef, txn.toMap());

    final sign = txn.type == 'income' ? 1 : -1;
    batch.update(_wallet(uid, txn.currency), {
      'balance': FieldValue.increment(sign * txn.amount),
    });

    return batch.commit().catchError((e) {
      reportError(e, userMessage: 'Failed to add transaction');
    });
  }

  /// Replaces an existing transaction, adjusting balances by the delta.
  /// Edits keep the original rateAtEntry (caller must preserve it).
  Future<void> updateTransaction(
    String uid,
    Transaction before,
    Transaction after,
  ) {
    final batch = _firestore.batch();
    final txnRef = _txns(uid).doc(after.id);
    batch.set(txnRef, after.toMap());

    final deltas = balanceDeltas(before, after);
    deltas.forEach((currency, delta) {
      batch.update(_wallet(uid, currency), {
        'balance': FieldValue.increment(delta),
      });
    });

    return batch.commit().catchError((e) {
      reportError(e, userMessage: 'Failed to update transaction');
    });
  }

  /// Deletes a transaction and reverses its balance impact.
  /// Undo rewrites the same doc id.
  Future<void> deleteTransaction(String uid, Transaction txn) {
    final batch = _firestore.batch();
    final txnRef = _txns(uid).doc(txn.id);
    batch.delete(txnRef);

    final sign = txn.type == 'income' ? -1 : 1;
    batch.update(_wallet(uid, txn.currency), {
      'balance': FieldValue.increment(sign * txn.amount),
    });

    return batch.commit().catchError((e) {
      reportError(e, userMessage: 'Failed to delete transaction');
    });
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.read(firestoreProvider));
});

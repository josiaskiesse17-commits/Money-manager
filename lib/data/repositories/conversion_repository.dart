import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/conversion.dart';

class ConversionRepository {
  ConversionRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference _conversions(String uid) =>
      _firestore.collection('users').doc(uid).collection('conversions');
  DocumentReference _wallet(String uid, String currency) => _firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc(currency);

  Stream<List<Conversion>> watchConversions(String uid) {
    return _conversions(uid).snapshots().map((snap) {
      return snap.docs.map((d) => Conversion.fromDocument(d)).toList();
    });
  }

  /// Records a conversion and updates both wallet balances.
  /// Not income/expense; excluded from budgets, charts, totals.
  Future<void> addConversion(String uid, Conversion conversion) {
    final batch = _firestore.batch();
    final ref = _conversions(uid).doc(conversion.id);
    batch.set(ref, conversion.toMap());

    // Debit from wallet
    batch.update(_wallet(uid, conversion.fromCurrency), {
      'balance': FieldValue.increment(-conversion.fromAmount),
    });
    // Credit to wallet
    batch.update(_wallet(uid, conversion.toCurrency), {
      'balance': FieldValue.increment(conversion.toAmount),
    });

    return batch.commit().catchError((e) {
      reportError(e, userMessage: 'Failed to record conversion');
    });
  }

  /// Deletes a conversion and reverses both wallet balances.
  Future<void> deleteConversion(String uid, Conversion conversion) {
    final batch = _firestore.batch();
    final ref = _conversions(uid).doc(conversion.id);
    batch.delete(ref);

    // Reverse: credit back from wallet
    batch.update(_wallet(uid, conversion.fromCurrency), {
      'balance': FieldValue.increment(conversion.fromAmount),
    });
    // Reverse: debit from to wallet
    batch.update(_wallet(uid, conversion.toCurrency), {
      'balance': FieldValue.increment(-conversion.toAmount),
    });

    return batch.commit().catchError((e) {
      reportError(e, userMessage: 'Failed to delete conversion');
    });
  }
}

final conversionRepositoryProvider = Provider<ConversionRepository>((ref) {
  return ConversionRepository(ref.read(firestoreProvider));
});

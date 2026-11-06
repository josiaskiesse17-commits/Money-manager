import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/debt_logic.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/models/debt_payment.dart';

/// Debts and debt payments.
///
/// Both directions are supported. Money stays in the debt's currency and a
/// payment uses the wallet of that currency. Debts and payments are NOT
/// income/expense: excluded from budgets, charts, month summary and reports.
class DebtRepository {
  DebtRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference _debts(String uid) =>
      _firestore.collection('users').doc(uid).collection('debts');
  CollectionReference _payments(String uid, String debtId) => _debts(uid)
      .doc(debtId)
      .collection('payments');
  DocumentReference _wallet(String uid, String currency) => _firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc(currency);

  Stream<List<Debt>> watchDebts(String uid, {bool includeArchived = false}) {
    return _debts(uid).snapshots().map((snap) {
      final list = snap.docs.map((d) => Debt.fromDocument(d)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!includeArchived) {
        return list.where((d) => !d.archived).toList();
      }
      return list;
    });
  }

  Stream<List<DebtPayment>> watchPayments(String uid, String debtId) {
    return _payments(uid, debtId).snapshots().map((snap) {
      return snap.docs
          .map((d) => DebtPayment.fromDocument(d))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Creates a debt in a single WriteBatch: the debt doc (remaining = principal)
  /// plus a wallet balance increment of [walletDeltaForNewDebt].
  Future<void> addDebt(String uid, Debt debt) {
    final batch = _firestore.batch();
    final debtRef = _debts(uid).doc(debt.id);
    batch.set(debtRef, debt.toMap());

    final delta = walletDeltaForNewDebt(debt.direction, debt.principal);
    batch.set(_wallet(uid, debt.currency), {
      'balance': FieldValue.increment(delta),
      'openingBalance': FieldValue.increment(0),
    }, SetOptions(merge: true));

    return batch.commit().catchError((e) {
      reportError(e);
      throw e;
    });
  }

  /// Records a payment in a single WriteBatch: the payment doc, the debt's
  /// `remaining` decremented by [payment.amount], and a wallet increment of
  /// [walletDeltaForPayment]. The caller must have validated the payment first.
  Future<void> addPayment(String uid, Debt debt, DebtPayment payment) {
    final batch = _firestore.batch();
    final paymentRef = _payments(uid, debt.id).doc(payment.id);
    batch.set(paymentRef, payment.toMap());

    final debtRef = _debts(uid).doc(debt.id);
    batch.update(debtRef, {'remaining': FieldValue.increment(-payment.amount)});

    final delta = walletDeltaForPayment(debt.direction, payment.amount);
    batch.set(_wallet(uid, debt.currency), {
      'balance': FieldValue.increment(delta),
      'openingBalance': FieldValue.increment(0),
    }, SetOptions(merge: true));

    return batch.commit().catchError((e) {
      reportError(e);
      throw e;
    });
  }

  /// Deletes a payment and reverses both the debt's `remaining` and the wallet.
  Future<void> deletePayment(String uid, Debt debt, DebtPayment payment) {
    final batch = _firestore.batch();
    final paymentRef = _payments(uid, debt.id).doc(payment.id);
    batch.delete(paymentRef);

    final debtRef = _debts(uid).doc(debt.id);
    batch.update(debtRef, {'remaining': FieldValue.increment(payment.amount)});

    final reverseDelta = -walletDeltaForPayment(debt.direction, payment.amount);
    batch.set(_wallet(uid, debt.currency), {
      'balance': FieldValue.increment(reverseDelta),
      'openingBalance': FieldValue.increment(0),
    }, SetOptions(merge: true));

    return batch.commit().catchError((e) {
      reportError(e);
      throw e;
    });
  }

  Future<void> archiveDebt(String uid, String debtId, bool archived) {
    return _debts(uid)
        .doc(debtId)
        .update({'archived': archived})
        .catchError((e) {
      reportError(e);
      throw e;
    });
  }

  /// Updates only `name`, `note` and `dueDate`. `principal`, `currency` and
  /// `direction` are immutable after creation.
  Future<void> updateDebt(String uid, Debt debt) {
    final debtRef = _debts(uid).doc(debt.id);
    return debtRef
        .update({
          'name': debt.name,
          'note': debt.note ?? '',
          if (debt.dueDate != null) 'dueDate': debt.dueDate,
        })
        .catchError((e) {
      reportError(e);
      throw e;
    });
  }
}

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref.read(firestoreProvider));
});

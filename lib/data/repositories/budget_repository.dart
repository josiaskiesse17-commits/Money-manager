import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/budget.dart';

class BudgetRepository {
  BudgetRepository(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference _budgetDoc(String uid, String categoryId) => _firestore
      .collection('users')
      .doc(uid)
      .collection('budgets')
      .doc(categoryId);

  Stream<Budget?> watchBudget(String uid, String categoryId) {
    return _budgetDoc(uid, categoryId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Budget.fromDocument(doc);
    });
  }

  Stream<List<Budget>> watchBudgets(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Budget.fromDocument(d)).toList());
  }

  Future<void> saveBudget(String uid, Budget budget) {
    return _budgetDoc(
      uid,
      budget.categoryId,
    ).set(budget.toMap(), SetOptions(merge: true)).catchError((e) {
      reportError(e, userMessage: 'Failed to save budget');
    });
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.read(firestoreProvider));
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/budget.dart';

class BudgetRepository {
  BudgetRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _budgetDoc(
    String uid,
    String categoryId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(categoryId);
  }

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
        .map((snapshot) => snapshot.docs.map(Budget.fromDocument).toList());
  }

  Future<void> saveBudget(String uid, Budget budget) async {
    try {
      await _budgetDoc(
        uid,
        budget.categoryId,
      ).set(budget.toMap(), SetOptions(merge: true));
    } catch (error, stackTrace) {
      reportError(error, userMessage: 'Failed to save budget');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.read(firestoreProvider));
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/category.dart';

class CategoryRepository {
  CategoryRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  Stream<List<Category>> watchCategories(
    String uid, {
    bool includeArchived = false,
  }) {
    return _collection(uid).snapshots().map((snap) {
      final list = snap.docs.map((d) => Category.fromDocument(d)).toList();
      if (!includeArchived) {
        return list.where((c) => !c.archived).toList();
      }
      return list;
    });
  }

  Stream<Category?> watchCategory(String uid, String id) {
    return _collection(uid).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Category.fromDocument(doc);
    });
  }

  Future<void> saveCategory(String uid, Category category) {
    return _collection(uid)
        .doc(category.id)
        .set(category.toMap(), SetOptions(merge: true))
        .catchError((e) {
          reportError(e, userMessage: 'Failed to save category');
        });
  }

  Future<void> archiveCategory(String uid, String id, bool archived) {
    return _collection(uid)
        .doc(id)
        .update({'archived': archived})
        .catchError((e) {
          reportError(e, userMessage: 'Failed to archive category');
        });
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.read(firestoreProvider));
});

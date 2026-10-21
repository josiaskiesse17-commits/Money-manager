import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/setting.dart';

class SettingsRepository {
  SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> settingsDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('main');
  }

  Stream<Setting?> watchSettings(String uid) {
    return settingsDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;

      return Setting.fromDocument(doc);
    });
  }

  Future<void> saveSettings(String uid, Setting setting) async {
    if (uid.trim().isEmpty) {
      final error = ArgumentError('Cannot save settings: user ID is empty.');

      reportError(
        error,
        userMessage: 'Cannot save settings: user ID is empty.',
      );

      throw error;
    }

    try {
      await settingsDoc(uid).set(setting.toMap(), SetOptions(merge: true));
    } catch (error, stackTrace) {
      reportError(
        error,
        userMessage: 'Failed to save settings. Please try again.',
      );

      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.read(firestoreProvider));
});

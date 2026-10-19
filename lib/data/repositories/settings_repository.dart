import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/app/error_reporter.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/setting.dart';

class SettingsRepository {
  SettingsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference settingsDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('main');

  Stream<Setting?> watchSettings(String uid) {
    return settingsDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Setting.fromDocument(doc);
    });
  }

  Future<void> saveSettings(String uid, Setting setting) async {
    if (uid.trim().isEmpty) {
      reportError(
        ArgumentError('Cannot save settings: user ID is empty.'),
        userMessage: 'Cannot save settings: user ID is empty.',
      );
      return;
    }

    // Fire-and-forget: offline futures only finish when the server answers.
    unawaited(
      settingsDoc(uid)
          .set(setting.toMap(), SetOptions(merge: true))
          .catchError((e) {
            reportError(
              e,
              userMessage: 'Failed to save settings. Please try again.',
            );
          }),
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.read(firestoreProvider));
});

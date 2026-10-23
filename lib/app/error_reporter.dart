import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

/// Global key for showing snackbars from anywhere (e.g. controllers).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Reports errors: logs in debug, optionally shows a snackbar.
/// Repositories that re-throw should call without [userMessage] so the
/// screen layer handles the user-facing message without duplication.
/// Offline writes are queued by Firestore and are not treated as errors here.
void reportError(Object error, {String? userMessage}) {
  if (kDebugMode) {
    debugPrint('Error: $error');
  }
  if (userMessage != null && userMessage.isNotEmpty) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(userMessage)),
    );
  }
}

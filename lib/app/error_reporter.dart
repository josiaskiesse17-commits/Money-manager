import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

/// Global key for showing snackbars from anywhere (e.g. controllers).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Reports errors: logs in debug, shows a snackbar for real failures.
/// Offline is not an error (Firestore queues writes).
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

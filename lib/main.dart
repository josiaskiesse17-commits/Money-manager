import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'app/app.dart';
import 'splash_remover.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore offline persistence: on web it only works in one tab.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  runApp(ProviderScope(child: const App()));

  // Remove the HTML web splash screen after Flutter renders its first frame.
  // web/index.html defines removeSplashFromWeb() but never calls it, so the
  // blue splash background (#0F5FA8) and <picture id="splash"> persist over
  // the app after it loads.
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removeSplashFromWeb();
    });
  }
}

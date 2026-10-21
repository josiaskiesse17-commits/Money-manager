import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/auth_gate.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/presentation/sign_in_screen.dart';
import 'package:money_manager/features/auth/presentation/verify_email_screen.dart';

List<Override> _overrides({
  required MockFirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
}) {
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

void main() {
  group('AuthGate', () {
    testWidgets('signed-out user is sent to sign in', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            auth: MockFirebaseAuth(),
            firestore: FakeFirebaseFirestore(),
          ),
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('signed-in unverified user is sent to verification', (
      tester,
    ) async {
      final mockAuth = MockFirebaseAuth(verifyEmailAutomatically: false);
      await mockAuth.createUserWithEmailAndPassword(
        email: 'unverified@example.com',
        password: 'password123',
      );
      await mockAuth.signInWithEmailAndPassword(
        email: 'unverified@example.com',
        password: 'password123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            auth: mockAuth,
            firestore: FakeFirebaseFirestore(),
          ),
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets('signed-in verified user passes verification', (tester) async {
      final mockAuth = MockFirebaseAuth();
      await mockAuth.createUserWithEmailAndPassword(
        email: 'verified@example.com',
        password: 'password123',
      );
      await mockAuth.signInWithEmailAndPassword(
        email: 'verified@example.com',
        password: 'password123',
      );

      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('test_uid')
          .collection('settings')
          .doc('main')
          .set({
            'usdToCdfRate': 280050,
            'theme': 'light',
            'displayMode': 'combined',
            'onboarded': true,
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(auth: mockAuth, firestore: firestore),
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      // Verification passed: neither the sign-in nor the verify screen shows.
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(VerifyEmailScreen), findsNothing);
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';

void main() {
  group('AuthProvider', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late ProviderContainer container;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is null (not signed in)', () {
      expect(container.read(authProvider), isNull);
    });

    test('successful signIn sets user state', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('test@example.com', 'password123');

      expect(notifier.signInError, isNull);
      await Future.delayed(const Duration(milliseconds: 100));
      final user = container.read(authProvider);
      expect(user, isNotNull);
      expect(user?.email, 'test@example.com');
    });

    test('successful signUp sets user state', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signUp('newuser@example.com', 'password123');

      expect(notifier.signUpError, isNull);
      await Future.delayed(const Duration(milliseconds: 100));
      final user = container.read(authProvider);
      expect(user, isNotNull);
      expect(user?.email, 'newuser@example.com');
    });

    test('signOut clears user state', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('test@example.com', 'password123');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(authProvider), isNotNull);

      await notifier.signOut();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(authProvider), isNull);
    });

    test('resetPassword sends email', () async {
      await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.resetPassword('test@example.com');

      expect(notifier.resetError, isNull);
      expect(notifier.resetSent, true);
    });

    test('signIn methods handle exceptions without crashing', () async {
      // firebase_auth_mocks does not throw for wrong credentials,
      // but the notifier catches exceptions gracefully
      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('nonexistent@example.com', 'password');
      await notifier.signUp('new@example.com', 'password123');
      await notifier.resetPassword('any@example.com');
      // Should not crash
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Email verification', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late ProviderContainer container;

    Future<void> signInAnUnverifiedUser() async {
      final notifier = container.read(authProvider.notifier);
      await mockAuth.createUserWithEmailAndPassword(
        email: 'unverified@example.com',
        password: 'password123',
      );
      await notifier.signIn('unverified@example.com', 'password123');
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setUp(() {
      // verifyEmailAutomatically: false so newly created accounts are NOT
      // verified — this matches real Firebase email/password behaviour.
      mockAuth = MockFirebaseAuth(verifyEmailAutomatically: false);
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

    test('newly registered email/password user is unverified', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.signUp('new@example.com', 'password123');
      expect(notifier.signUpError, isNull);

      await Future.delayed(const Duration(milliseconds: 100));
      final user = container.read(authProvider);
      expect(user, isNotNull);
      expect(user?.email, 'new@example.com');
      expect(container.read(authProvider.notifier).isEmailVerified, isFalse);
    });

    test('signed-in but unverified user cannot proceed', () async {
      await signInAnUnverifiedUser();

      final notifier = container.read(authProvider.notifier);
      await notifier.signIn('unverified@example.com', 'password123');
      await Future.delayed(const Duration(milliseconds: 100));

      final user = container.read(authProvider);
      expect(user, isNotNull);
      expect(user?.emailVerified, isFalse);
      expect(notifier.isEmailVerified, isFalse);
    });

    test('verified user can proceed normally', () async {
      // verifyEmailAutomatically defaults to true: accounts are verified.
      final verifiedAuth = MockFirebaseAuth();
      final verifiedFirestore = FakeFirebaseFirestore();
      final verifiedContainer = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(verifiedAuth),
          firestoreProvider.overrideWithValue(verifiedFirestore),
        ],
      );

      try {
        final notifier = verifiedContainer.read(authProvider.notifier);
        await notifier.signUp('verified@example.com', 'password123');
        expect(notifier.signUpError, isNull);

        await Future.delayed(const Duration(milliseconds: 100));
        final user = verifiedContainer.read(authProvider);
        expect(user, isNotNull);
        expect(user?.emailVerified, isTrue);
        expect(notifier.isEmailVerified, isTrue);
      } finally {
        verifiedContainer.dispose();
      }
    });

    test(
      'reloading verification status after verification allows proceeding',
      () async {
        await signInAnUnverifiedUser();
        await Future.delayed(const Duration(milliseconds: 100));

        final notifier = container.read(authProvider.notifier);
        expect(notifier.isEmailVerified, isFalse);

        // Simulate the user clicking the verification link: replace the mock
        // user with a verified copy (as Firebase reload would surface), then
        // reload through the notifier.
        final current = mockAuth.currentUser!;
        mockAuth.mockUser = MockUser(
          isEmailVerified: true,
          uid: current.uid,
          email: current.email,
        );

        await notifier.reloadUser();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(notifier.isEmailVerified, isTrue);
        expect(container.read(authProvider)?.emailVerified, isTrue);
      },
    );

    test('resending verification email calls sendEmailVerification', () async {
      await signInAnUnverifiedUser();
      await Future.delayed(const Duration(milliseconds: 100));

      final notifier = container.read(authProvider.notifier);
      await notifier.sendEmailVerification();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.verificationError, isNull);
    });

    test('resend with no signed-in user is handled safely', () async {
      // No user signed in.
      final notifier = container.read(authProvider.notifier);
      await notifier.sendEmailVerification();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.verificationError, isNotNull);
    });

    test('reload with no signed-in user is handled safely', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.reloadUser();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.verificationError, isNotNull);
    });

    test('signing out clears the session', () async {
      await signInAnUnverifiedUser();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(authProvider), isNotNull);

      final notifier = container.read(authProvider.notifier);
      await notifier.signOut();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(container.read(authProvider), isNull);
      expect(notifier.isEmailVerified, isFalse);
    });

    test('sign in and sign up remain functional', () async {
      final notifier = container.read(authProvider.notifier);

      await notifier.signUp('reg@example.com', 'password123');
      expect(notifier.signUpError, isNull);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(authProvider), isNotNull);

      await notifier.signOut();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(authProvider), isNull);

      await notifier.signIn('reg@example.com', 'password123');
      expect(notifier.signInError, isNull);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(authProvider), isNotNull);
      expect(container.read(authProvider)?.email, 'reg@example.com');
    });
  });
}

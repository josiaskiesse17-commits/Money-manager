import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/features/settings/application/settings_provider.dart';

void main() {
  group('SettingsProvider', () {
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

    Future<void> waitForStream() async {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    String getUid(UserCredential credential) => credential.user!.uid;

    test(
      'new user: settings stream emits null when no settings document exists',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'new@example.com',
          password: 'password123',
        );
        await mockAuth.signInWithEmailAndPassword(
          email: 'new@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        container.read(settingsProvider(uid));
        await waitForStream();

        expect(container.read(settingsProvider(uid)).value, isNull);
      },
    );

    test('existing user with settings: stream emits the Setting', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'existing@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('main')
          .set({
            'usdToCdfRate': 280050,
            'theme': 'dark',
            'displayMode': 'combined',
            'onboarded': true,
          });

      container.read(settingsProvider(uid));
      await waitForStream();

      final state = container.read(settingsProvider(uid));
      expect(state.value?.usdToCdfRate, 280050);
      expect(state.value?.theme, 'dark');
      expect(state.value?.onboarded, true);
    });

    test(
      'existing user with NO settings document: emits null (needs onboarding)',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'nosettings@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        container.read(settingsProvider(uid));
        await waitForStream();

        expect(container.read(settingsProvider(uid)).value, isNull);
      },
    );

    test('save settings then read them back', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'save@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      final notifier = container.read(settingsProvider(uid).notifier);
      await notifier.save(
        const Setting(
          docId: 'main',
          usdToCdfRate: 280050,
          theme: 'light',
          displayMode: 'cdf',
          onboarded: true,
        ),
      );

      await waitForStream();

      final state = container.read(settingsProvider(uid));
      expect(state.value?.usdToCdfRate, 280050);
      expect(state.value?.theme, 'light');
      expect(state.value?.onboarded, true);
    });

    test('settings stream error handling', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'error@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      final brokenFirestore = FakeFirebaseFirestore();
      await brokenFirestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('main')
          .set({'usdToCdfRate': 'not-an-int'});

      final errorContainer = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          firestoreProvider.overrideWithValue(brokenFirestore),
        ],
      );

      try {
        errorContainer.read(settingsProvider(uid));
        await waitForStream();

        final state = errorContainer.read(settingsProvider(uid));
        expect(state.hasError, true);
      } finally {
        errorContainer.dispose();
      }
    });

    test(
      'signed out user: settings provider with empty uid emits null',
      () async {
        await mockAuth.createUserWithEmailAndPassword(
          email: 'signedout@example.com',
          password: 'password123',
        );

        await mockAuth.signOut();
        expect(mockAuth.currentUser, isNull);

        container.read(settingsProvider(''));
        await waitForStream();

        expect(container.read(settingsProvider('')).value, isNull);
      },
    );
  });
}

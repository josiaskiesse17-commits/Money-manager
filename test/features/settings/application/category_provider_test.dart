import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/categories/application/category_provider.dart';

void main() {
  group('CategoryProvider', () {
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

    test('new category can be saved and read back', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      final notifier = container.read(categoryProvider(uid).notifier);
      await notifier.save(
        const Category(
          id: 'cat_food',
          name: 'Food',
          icon: 'category',
          color: 0xFFC73E2E,
          type: 'expense',
          archived: false,
        ),
      );

      await waitForStream();

      final state = container.read(categoryProvider(uid));
      expect(state.value, isNotNull);
      expect(state.value?.length, 1);
      expect(state.value?.first.id, 'cat_food');
      expect(state.value?.first.name, 'Food');
      expect(state.value?.first.type, 'expense');
    });

    test(
      'editing updates existing category instead of creating duplicate',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        final notifier = container.read(categoryProvider(uid).notifier);
        await notifier.save(
          const Category(
            id: 'cat_food',
            name: 'Food',
            icon: 'category',
            color: 0xFFC73E2E,
            type: 'expense',
            archived: false,
          ),
        );
        await waitForStream();

        // Edit: save same id with a new name
        await notifier.save(
          const Category(
            id: 'cat_food',
            name: 'Groceries',
            icon: 'shopping_cart',
            color: 0xFF1B8A4B,
            type: 'expense',
            archived: false,
          ),
        );
        await waitForStream();

        final state = container.read(categoryProvider(uid));
        expect(state.value?.length, 1); // One category, not two
        expect(state.value?.first.id, 'cat_food'); // Identity preserved
        expect(state.value?.first.name, 'Groceries'); // Updated value
      },
    );

    test('archive and restore preserves category identity', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      final notifier = container.read(categoryProvider(uid).notifier);
      await notifier.save(
        const Category(
          id: 'cat_food',
          name: 'Food',
          icon: 'category',
          color: 0xFFC73E2E,
          type: 'expense',
          archived: false,
        ),
      );
      await waitForStream();

      await notifier.archive('cat_food', true);
      await waitForStream();

      // Non-archived watch excludes it
      final active = container.read(categoryProvider(uid));
      expect(active.value?.length, 0);

      // Restore
      await notifier.archive('cat_food', false);
      await waitForStream();

      final restored = container.read(categoryProvider(uid));
      expect(restored.value?.length, 1);
      expect(restored.value?.first.id, 'cat_food');
      expect(restored.value?.first.archived, isFalse);
    });
  });
}

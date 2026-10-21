import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/features/budgets/application/budget_provider.dart';

void main() {
  group('BudgetProvider', () {
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

    test('new budget can be saved and read back', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      final notifier = container.read(budgetProvider(uid).notifier);
      await notifier.save(
        const Budget(
          categoryId: 'cat_food',
          currency: 'CDF',
          monthlyLimit: 50000,
        ),
      );

      await waitForStream();

      final state = container.read(budgetProvider(uid));
      expect(state.value, isNotNull);
      expect(state.value?.length, 1);
      expect(state.value?.first.categoryId, 'cat_food');
      expect(state.value?.first.currency, 'CDF');
      expect(state.value?.first.monthlyLimit, 50000);
    });

    test(
      'editing updates existing budget instead of creating duplicate',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        final notifier = container.read(budgetProvider(uid).notifier);
        await notifier.save(
          const Budget(
            categoryId: 'cat_food',
            currency: 'CDF',
            monthlyLimit: 50000,
          ),
        );
        await waitForStream();

        // Edit: save the same categoryId with a new limit
        await notifier.save(
          const Budget(
            categoryId: 'cat_food',
            currency: 'CDF',
            monthlyLimit: 75000,
          ),
        );
        await waitForStream();

        final state = container.read(budgetProvider(uid));
        expect(state.value?.length, 1); // One budget, not two
        expect(state.value?.first.monthlyLimit, 75000); // Updated value
      },
    );

    test(
      'budget with zero monthlyLimit is saved (mock does not enforce rules)',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        final notifier = container.read(budgetProvider(uid).notifier);
        await notifier.save(
          const Budget(
            categoryId: 'cat_food',
            currency: 'CDF',
            monthlyLimit: 0,
          ),
        );
        await waitForStream();

        // fake_cloud_firestore does not enforce Firestore security rules,
        // so the budget is saved despite monthlyLimit=0 violating positiveInt rule
        final state = container.read(budgetProvider(uid));
        expect(state.value?.length, 1);
        expect(state.value?.first.monthlyLimit, 0);
      },
    );

    test('USD budget saves with correct minor units', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      final notifier = container.read(budgetProvider(uid).notifier);
      await notifier.save(
        const Budget(
          categoryId: 'cat_food',
          currency: 'USD',
          monthlyLimit: 12500, // $125.00
        ),
      );
      await waitForStream();

      final state = container.read(budgetProvider(uid));
      expect(state.value?.length, 1);
      expect(state.value?.first.currency, 'USD');
      expect(state.value?.first.monthlyLimit, 12500);
    });
  });
}

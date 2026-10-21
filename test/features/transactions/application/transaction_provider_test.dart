import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/features/transactions/application/transaction_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transaction rateAtEntry', () {
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

    test('new transaction stores rateAtEntry from settings', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
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
            'theme': 'light',
            'displayMode': 'combined',
            'onboarded': true,
          });
      await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .set({'currency': 'USD', 'openingBalance': 10000, 'balance': 10000});
      await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('CDF')
          .set({'currency': 'CDF', 'openingBalance': 0, 'balance': 0});

      final notifier = container.read(transactionProvider(uid).notifier);
      await notifier.add(
        Transaction(
          id: 'txn_1',
          amount: 10000,
          currency: 'USD',
          type: 'expense',
          categoryId: 'cat_food',
          date: DateTime(2026, 1, 15),
          rateAtEntry: 280050,
          createdAt: DateTime(2026, 1, 15),
        ),
      );

      await waitForStream();

      final state = container.read(transactionProvider(uid));
      expect(state.value?.length, 1);
      expect(state.value?.first.rateAtEntry, 280050);
      expect(state.value?.first.amount, 10000);
      expect(state.value?.first.currency, 'USD');
    });

    test(
      'editing preserves original rateAtEntry when settings rate differs',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('main')
            .set({
              'usdToCdfRate': 999999,
              'theme': 'light',
              'displayMode': 'combined',
              'onboarded': true,
            });
        await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('USD')
            .set({
              'currency': 'USD',
              'openingBalance': 10000,
              'balance': 10000,
            });
        await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .set({'currency': 'CDF', 'openingBalance': 0, 'balance': 0});

        final notifier = container.read(transactionProvider(uid).notifier);
        await notifier.add(
          Transaction(
            id: 'txn_1',
            amount: 10000,
            currency: 'USD',
            type: 'expense',
            categoryId: 'cat_food',
            date: DateTime(2026, 1, 15),
            rateAtEntry: 280050,
            createdAt: DateTime(2026, 1, 15),
          ),
        );
        await waitForStream();

        // Edit: change amount but preserve original rateAtEntry (caller responsibility)
        final original = container.read(transactionProvider(uid)).value!.first;
        await notifier.update(original, original.copyWith(amount: 20000));
        await waitForStream();

        final updated = container.read(transactionProvider(uid)).value!.first;
        expect(updated.rateAtEntry, 280050); // Original rate preserved
        expect(updated.amount, 20000); // Amount changed
      },
    );

    test('Transaction round-trips rateAtEntry through serialization', () {
      final txn = Transaction(
        id: 'txn_1',
        amount: 5000,
        currency: 'USD',
        type: 'income',
        categoryId: 'cat_salary',
        date: DateTime(2026, 1, 15),
        rateAtEntry: 280050,
        createdAt: DateTime(2026, 1, 15),
      );
      final map = txn.toMap();
      final restored = Transaction.fromMap('txn_1', map);
      expect(restored.rateAtEntry, 280050);
      expect(restored.amount, 5000);
      expect(restored.currency, 'USD');
    });
  });
}

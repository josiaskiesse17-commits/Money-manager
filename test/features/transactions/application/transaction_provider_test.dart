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

  group('Transaction delete and Undo', () {
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

    Future<void> setupUser(String uid, {int usdRate = 280050}) async {
      await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('main')
          .set({
            'usdToCdfRate': usdRate,
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
    }

    test('deleting expense USD transaction reduces wallet balance; Undo restores it', () async {
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      final uid = getUid(credential);

      await setupUser(uid);

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

      final walletBefore = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(walletBefore.data()!['balance'], 0); // 10000 - 10000 = 0

      final txn = container.read(transactionProvider(uid)).value!.first;
      await container.read(transactionProvider(uid).notifier).delete(txn);
      await waitForStream();

      final walletAfterDelete = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(walletAfterDelete.data()!['balance'], 10000); // 0 + 10000 = 10000

      await container.read(transactionProvider(uid).notifier).restore(txn);
      await waitForStream();

      final walletAfterUndo = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(walletAfterUndo.data()!['balance'], 0); // Back to 0

      final state = container.read(transactionProvider(uid));
      expect(state.value?.length, 1);
      expect(state.value?.first.id, 'txn_1');
      expect(state.value?.first.amount, 10000);
    });

    test(
      'deleting income USD transaction; Undo restores wallet balance',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        await setupUser(uid);

        final notifier = container.read(transactionProvider(uid).notifier);
        await notifier.add(
          Transaction(
            id: 'txn_2',
            amount: 5000,
            currency: 'USD',
            type: 'income',
            categoryId: 'cat_salary',
            date: DateTime(2026, 1, 15),
            rateAtEntry: 280050,
            createdAt: DateTime(2026, 1, 15),
          ),
        );
        await waitForStream();

        final walletBefore = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('USD')
            .get();
        expect(walletBefore.data()!['balance'], 15000); // 10000 + 5000

        final txn = container.read(transactionProvider(uid)).value!.first;
        await notifier.delete(txn);
        await waitForStream();

        final walletAfterDelete = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('USD')
            .get();
        expect(walletAfterDelete.data()!['balance'], 10000); // 15000 - 5000

        await notifier.restore(txn);
        await waitForStream();

        final walletAfterUndo = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('USD')
            .get();
        expect(walletAfterUndo.data()!['balance'], 15000); // Back to 15000

        final state = container.read(transactionProvider(uid));
        expect(state.value?.length, 1);
        expect(state.value?.first.id, 'txn_2');
        expect(state.value?.first.amount, 5000);
      },
    );

    test(
      'deleting expense CDF transaction; Undo restores wallet balance',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        await setupUser(uid);
        await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .set({
              'currency': 'CDF',
              'openingBalance': 500000,
              'balance': 500000,
            });

        final notifier = container.read(transactionProvider(uid).notifier);
        await notifier.add(
          Transaction(
            id: 'txn_3',
            amount: 50000,
            currency: 'CDF',
            type: 'expense',
            categoryId: 'cat_transport',
            date: DateTime(2026, 1, 15),
            rateAtEntry: 280050,
            createdAt: DateTime(2026, 1, 15),
          ),
        );
        await waitForStream();

        final walletBefore = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .get();
        expect(walletBefore.data()!['balance'], 450000); // 500000 - 50000

        final txn = container.read(transactionProvider(uid)).value!.first;
        await notifier.delete(txn);
        await waitForStream();

        final walletAfterDelete = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .get();
        expect(walletAfterDelete.data()!['balance'], 500000); // 450000 + 50000

        await notifier.restore(txn);
        await waitForStream();

        final walletAfterUndo = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .get();
        expect(walletAfterUndo.data()!['balance'], 450000); // Back to 450000

        final state = container.read(transactionProvider(uid));
        expect(state.value?.length, 1);
        expect(state.value?.first.id, 'txn_3');
        expect(state.value?.first.amount, 50000);
      },
    );

    test(
      'deleting income CDF transaction; Undo restores wallet balance',
      () async {
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        final uid = getUid(credential);

        await setupUser(uid);
        await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .set({
              'currency': 'CDF',
              'openingBalance': 500000,
              'balance': 500000,
            });

        final notifier = container.read(transactionProvider(uid).notifier);
        await notifier.add(
          Transaction(
            id: 'txn_4',
            amount: 25000,
            currency: 'CDF',
            type: 'income',
            categoryId: 'cat_business',
            date: DateTime(2026, 1, 15),
            rateAtEntry: 280050,
            createdAt: DateTime(2026, 1, 15),
          ),
        );
        await waitForStream();

        final walletBefore = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .get();
        expect(walletBefore.data()!['balance'], 525000); // 500000 + 25000

        final txn = container.read(transactionProvider(uid)).value!.first;
        await notifier.delete(txn);
        await waitForStream();

        final walletAfterDelete = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .get();
        expect(walletAfterDelete.data()!['balance'], 500000); // 525000 - 25000

        await notifier.restore(txn);
        await waitForStream();

        final walletAfterUndo = await mockFirestore
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc('CDF')
            .get();
        expect(walletAfterUndo.data()!['balance'], 525000); // Back to 525000

        final state = container.read(transactionProvider(uid));
        expect(state.value?.length, 1);
        expect(state.value?.first.id, 'txn_4');
        expect(state.value?.first.amount, 25000);
      },
    );
  });
}

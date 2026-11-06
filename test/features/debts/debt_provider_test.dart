import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/models/debt_payment.dart';
import 'package:money_manager/features/debts/application/debt_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DebtStateNotifier', () {
    late FakeFirebaseFirestore mockFirestore;
    late ProviderContainer container;
    late String uid;

    setUp(() async {
      mockFirestore = FakeFirebaseFirestore();

      final mockAuth = MockFirebaseAuth();
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      uid = credential.user!.uid;

      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );

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
          .set({'currency': 'CDF', 'openingBalance': 500000, 'balance': 500000});
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> waitForStream() async {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    DebtStateNotifier notifier() {
      return container.read(debtProvider(uid).notifier);
    }

    test('add debt owe increases wallet and sets remaining = principal', () async {
      await notifier().addDebt(Debt(
        id: 'debt_1',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 50000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      ));
      await waitForStream();

      final wallet = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(wallet.data()!['balance'], 60000);

      final state = container.read(debtProvider(uid));
      expect(state.value?.length, 1);
      expect(state.value?.first.remaining, 50000);
    });

    test('add debt owed decreases wallet and sets remaining = principal', () async {
      await notifier().addDebt(Debt(
        id: 'debt_2',
        name: 'Personal loan',
        direction: 'owed',
        currency: 'CDF',
        principal: 100000,
        remaining: 100000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      ));
      await waitForStream();

      final wallet = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('CDF')
          .get();
      expect(wallet.data()!['balance'], 400000);
    });

    test('add payment owe decreases wallet and remaining', () async {
      final debt = Debt(
        id: 'debt_3',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 30000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await notifier().addDebt(debt);
      await waitForStream();

      await notifier().addPayment(debt, DebtPayment(
        id: 'pay_1',
        debtId: 'debt_3',
        amount: 10000,
        currency: 'USD',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      ));
      await waitForStream();

      final wallet = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(wallet.data()!['balance'], 50000);

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_3')
          .get();
      expect(saved.data()!['remaining'], 20000);
    });

    test('add payment owed increases wallet and decreases remaining', () async {
      final debt = Debt(
        id: 'debt_4',
        name: 'Personal loan',
        direction: 'owed',
        currency: 'CDF',
        principal: 100000,
        remaining: 60000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await notifier().addDebt(debt);
      await waitForStream();

      await notifier().addPayment(debt, DebtPayment(
        id: 'pay_2',
        debtId: 'debt_4',
        amount: 20000,
        currency: 'CDF',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      ));
      await waitForStream();

      final wallet = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('CDF')
          .get();
      expect(wallet.data()!['balance'], 420000);

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_4')
          .get();
      expect(saved.data()!['remaining'], 40000);
    });

    test('add payment invalid amount throws and does not write', () async {
      final debt = Debt(
        id: 'debt_5',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 10000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await notifier().addDebt(debt);
      await waitForStream();

      final before = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      final beforeBalance = before.data()!['balance'];

      expect(
        () async => notifier().addPayment(debt, DebtPayment(
          id: 'pay_bad',
          debtId: 'debt_5',
          amount: 20000,
          currency: 'USD',
          date: DateTime(2026, 1, 15),
          createdAt: DateTime(2026, 1, 15),
        )),
        throwsA(isA<StateError>()),
      );

      final after = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(after.data()!['balance'], beforeBalance);

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_5')
          .get();
      expect(saved.data()!['remaining'], 10000);
    });

    test('add payment zero amount throws', () async {
      final debt = Debt(
        id: 'debt_6',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 10000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await notifier().addDebt(debt);
      await waitForStream();

      expect(
        () async => notifier().addPayment(debt, DebtPayment(
          id: 'pay_zero',
          debtId: 'debt_6',
          amount: 0,
          currency: 'USD',
          date: DateTime(2026, 1, 15),
          createdAt: DateTime(2026, 1, 15),
        )),
        throwsA(isA<StateError>()),
      );
    });

    test('delete payment restores wallet and remaining', () async {
      final debt = Debt(
        id: 'debt_7',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 30000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await notifier().addDebt(debt);
      await waitForStream();

      await notifier().addPayment(debt, DebtPayment(
        id: 'pay_3',
        debtId: 'debt_7',
        amount: 10000,
        currency: 'USD',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      ));
      await waitForStream();

      await notifier().deletePayment(debt, DebtPayment(
        id: 'pay_3',
        debtId: 'debt_7',
        amount: 10000,
        currency: 'USD',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      ));
      await waitForStream();

      final wallet = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(wallet.data()!['balance'], 60000);

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_7')
          .get();
      expect(saved.data()!['remaining'], 30000);
    });

    test('archive flips archived only, no balance change', () async {
      await notifier().addDebt(Debt(
        id: 'debt_8',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 30000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      ));
      await waitForStream();

      await notifier().archiveDebt('debt_8', true);
      await waitForStream();

      final wallet = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(wallet.data()!['balance'], 60000);

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_8')
          .get();
      expect(saved.data()!['archived'], true);

      // Unarchive restores archived=false without touching balance.
      await notifier().archiveDebt('debt_8', false);
      await waitForStream();
      final unarchived = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_8')
          .get();
      expect(unarchived.data()!['archived'], false);
    });

    test('updateDebt changes name, note and dueDate only', () async {
      final now = DateTime(2026, 1, 1);
      await notifier().addDebt(Debt(
        id: 'debt_9',
        name: 'Old name',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 50000,
        archived: false,
        createdAt: now,
      ));
      await waitForStream();

      final updated = Debt(
        id: 'debt_9',
        name: 'New name',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 50000,
        dueDate: DateTime(2026, 2, 1),
        note: 'New note',
        archived: false,
        createdAt: now,
      );
      await notifier().updateDebt(updated);
      await waitForStream();

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_9')
          .get();
      final data = saved.data()!;
      expect(data['name'], 'New name');
      expect(data['note'], 'New note');
      expect(data['principal'], 50000); // unchanged
      expect(data['direction'], 'owe'); // unchanged
      expect(data['currency'], 'USD'); // unchanged
    });

    test('watchDebts streams debts newest first', () async {
      final now = DateTime(2026, 1, 1);
      await notifier().addDebt(Debt(
        id: 'debt_a', name: 'A', direction: 'owe', currency: 'USD',
        principal: 1000, remaining: 1000, archived: false, createdAt: now,
      ));
      await notifier().addDebt(Debt(
        id: 'debt_b', name: 'B', direction: 'owe', currency: 'USD',
        principal: 2000, remaining: 2000, archived: false,
        createdAt: now.add(const Duration(days: 1)),
      ));
      await waitForStream();

      final state = container.read(debtProvider(uid));
      expect(state.value!.length, 2);
      expect(state.value!.first.id, 'debt_b');
      expect(state.value!.last.id, 'debt_a');
    });
  });
}

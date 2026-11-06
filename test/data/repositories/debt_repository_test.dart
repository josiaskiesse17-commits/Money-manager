import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models/debt.dart';
import 'package:money_manager/data/models/debt_payment.dart';
import 'package:money_manager/data/repositories/debt_repository.dart';

void main() {
  group('DebtRepository', () {
    late FakeFirebaseFirestore mockFirestore;
    late String uid;

    setUp(() async {
      mockFirestore = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final credential = await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      uid = credential.user!.uid;

      // Seed both wallets so balance increments never fail on a missing doc.
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

    Future<Map<String, dynamic>> walletSnapshot(String currency) async {
      final doc = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc(currency)
          .get();
      return doc.data() as Map<String, dynamic>;
    }

    test('add debt owe increases wallet and sets remaining = principal', () async {
      final repo = DebtRepository(mockFirestore);
      final debt = Debt(
        id: 'debt_1',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 50000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );

      await repo.addDebt(uid, debt);

      final wallet = await walletSnapshot('USD');
      expect(wallet['balance'], 60000); // 10000 + 50000

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_1')
          .get();
      expect(saved.data()!['remaining'], 50000);
      expect(saved.data()!['archived'], false);
    });

    test('add debt owed decreases wallet and sets remaining = principal', () async {
      final repo = DebtRepository(mockFirestore);
      final debt = Debt(
        id: 'debt_2',
        name: 'Personal loan',
        direction: 'owed',
        currency: 'CDF',
        principal: 100000,
        remaining: 100000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );

      await repo.addDebt(uid, debt);

      final wallet = await walletSnapshot('CDF');
      expect(wallet['balance'], 400000); // 500000 - 100000
    });

    test('add payment owe decreases wallet and remaining', () async {
      final repo = DebtRepository(mockFirestore);
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
      await repo.addDebt(uid, debt);

      final payment = DebtPayment(
        id: 'pay_1',
        debtId: 'debt_3',
        amount: 10000,
        currency: 'USD',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      );

      await repo.addPayment(uid, debt, payment);

      final wallet = await walletSnapshot('USD');
      expect(wallet['balance'], 50000); // 60000 - 10000

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_3')
          .get();
      expect(saved.data()!['remaining'], 20000); // 30000 - 10000
    });

    test('add payment owed increases wallet and decreases remaining', () async {
      final repo = DebtRepository(mockFirestore);
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
      await repo.addDebt(uid, debt);

      final payment = DebtPayment(
        id: 'pay_2',
        debtId: 'debt_4',
        amount: 20000,
        currency: 'CDF',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      );

      await repo.addPayment(uid, debt, payment);

      final wallet = await walletSnapshot('CDF');
      expect(wallet['balance'], 420000); // 400000 + 20000

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_4')
          .get();
      expect(saved.data()!['remaining'], 40000); // 60000 - 20000
    });

    test('delete payment restores wallet and remaining', () async {
      final repo = DebtRepository(mockFirestore);
      final debt = Debt(
        id: 'debt_5',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 30000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await repo.addDebt(uid, debt);

      final payment = DebtPayment(
        id: 'pay_3',
        debtId: 'debt_5',
        amount: 10000,
        currency: 'USD',
        date: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      );
      await repo.addPayment(uid, debt, payment);

      await repo.deletePayment(uid, debt, payment);

      final wallet = await walletSnapshot('USD');
      expect(wallet['balance'], 60000); // back to post-debt value

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_5')
          .get();
      expect(saved.data()!['remaining'], 30000); // back to post-debt value

      final paymentDoc = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_5')
          .collection('payments')
          .doc('pay_3')
          .get();
      expect(paymentDoc.exists, false);
    });

    test('archive flips archived only, no balance change', () async {
      final repo = DebtRepository(mockFirestore);
      final debt = Debt(
        id: 'debt_6',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 30000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await repo.addDebt(uid, debt);

      await repo.archiveDebt(uid, 'debt_6', true);

      final wallet = await walletSnapshot('USD');
      expect(wallet['balance'], 60000); // unchanged

      final saved = await mockFirestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc('debt_6')
          .get();
      expect(saved.data()!['archived'], true);
    });

    test('other currency wallet untouched when debt is in USD', () async {
      final repo = DebtRepository(mockFirestore);
      final debt = Debt(
        id: 'debt_7',
        name: 'Phone loan',
        direction: 'owe',
        currency: 'USD',
        principal: 50000,
        remaining: 50000,
        archived: false,
        createdAt: DateTime(2026, 1, 1),
      );
      await repo.addDebt(uid, debt);

      final cdfWallet = await walletSnapshot('CDF');
      expect(cdfWallet['balance'], 500000); // untouched
    });

    group('watchDebts', () {
      test('returns debts newest first and excludes archived by default', () async {
        final repo = DebtRepository(mockFirestore);
        final now = DateTime(2026, 1, 1);
        await repo.addDebt(uid, Debt(
          id: 'debt_a', name: 'A', direction: 'owe', currency: 'USD',
          principal: 1000, remaining: 1000, archived: false, createdAt: now,
        ));
        await repo.addDebt(uid, Debt(
          id: 'debt_b', name: 'B', direction: 'owe', currency: 'USD',
          principal: 2000, remaining: 2000, archived: false,
          createdAt: now.add(const Duration(days: 1)),
        ));
        await repo.addDebt(uid, Debt(
          id: 'debt_c', name: 'C', direction: 'owe', currency: 'USD',
          principal: 3000, remaining: 3000, archived: true,
          createdAt: now.add(const Duration(days: 2)),
        ));

        final debts = await repo.watchDebts(uid).first;
        expect(debts.length, 2);
        expect(debts.first.id, 'debt_b'); // newest first
        expect(debts.last.id, 'debt_a');

        final all = await repo.watchDebts(uid, includeArchived: true).first;
        expect(all.length, 3);
      });
    });

    group('watchPayments', () {
      test('returns payments newest first for a debt', () async {
        final repo = DebtRepository(mockFirestore);
        final debt = Debt(
          id: 'debt_8', name: 'Phone loan', direction: 'owe', currency: 'USD',
          principal: 50000, remaining: 30000, archived: false,
          createdAt: DateTime(2026, 1, 1),
        );
        await repo.addDebt(uid, debt);

        final now = DateTime(2026, 1, 15);
        await repo.addPayment(uid, debt, DebtPayment(
          id: 'pay_a', debtId: 'debt_8', amount: 5000, currency: 'USD',
          date: now, createdAt: now,
        ));
        await repo.addPayment(uid, debt, DebtPayment(
          id: 'pay_b', debtId: 'debt_8', amount: 3000, currency: 'USD',
          date: now.add(const Duration(days: 1)), createdAt: now.add(const Duration(days: 1)),
        ));

        final payments = await repo.watchPayments(uid, 'debt_8').first;
        expect(payments.length, 2);
        expect(payments.first.id, 'pay_b'); // newest first
        expect(payments.last.id, 'pay_a');
      });
    });
  });
}

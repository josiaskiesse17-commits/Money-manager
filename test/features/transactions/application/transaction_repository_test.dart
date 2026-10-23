import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/repositories/transaction_repository.dart';

const _uid = 'test_uid';

Future<void> _seedWallets(FakeFirebaseFirestore firestore, String uid) async {
  await firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc('USD')
      .set({'currency': 'USD', 'openingBalance': 10000, 'balance': 10000});
  await firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc('CDF')
      .set({'currency': 'CDF', 'openingBalance': 0, 'balance': 0});
}

class FailingTransactionRepository extends TransactionRepository {
  FailingTransactionRepository(super.firestore);

  @override
  Future<void> addTransaction(String uid, Transaction txn) async {
    throw Exception('Simulated transaction write failure');
  }

  @override
  Future<void> updateTransaction(
    String uid,
    Transaction before,
    Transaction after,
  ) async {
    throw Exception('Simulated transaction update failure');
  }

  @override
  Future<void> restoreTransaction(String uid, Transaction txn) async {
    throw Exception('Simulated transaction restore failure');
  }

  @override
  Future<void> deleteTransaction(String uid, Transaction txn) async {
    throw Exception('Simulated transaction delete failure');
  }
}

void main() {
  group('TransactionRepository with fake Firestore', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late ProviderContainer container;

    setUp(() {
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: _uid),
      );
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

    group('TransactionRepository.addTransaction', () {
      test(
        'successfully adds transaction and updates wallet balance',
        () async {
          await _seedWallets(mockFirestore, _uid);

          final repo = TransactionRepository(mockFirestore);
          await repo.addTransaction(
            _uid,
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

          // Verify transaction was written
          final txnDoc = await mockFirestore
              .collection('users')
              .doc(_uid)
              .collection('transactions')
              .doc('txn_1')
              .get();
          expect(txnDoc.exists, isTrue);
          expect(txnDoc.data()!['amount'], 10000);

          // Verify wallet balance updated (expense: -10000)
          final usdBal = await mockFirestore
              .collection('users')
              .doc(_uid)
              .collection('wallets')
              .doc('USD')
              .get();
          expect(usdBal.data()!['balance'], 0); // 10000 - 10000 = 0
        },
      );

      test(
        'throws when write fails (error propagates, not swallowed)',
        () async {
          final mockFirestore = FakeFirebaseFirestore();
          await mockFirestore
              .collection('users')
              .doc(_uid)
              .collection('wallets')
              .doc('USD')
              .set({
                'currency': 'USD',
                'openingBalance': 10000,
                'balance': 10000,
              });

          final container = ProviderContainer(
            overrides: [
              firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
              transactionRepositoryProvider.overrideWithValue(
                FailingTransactionRepository(FakeFirebaseFirestore()),
              ),
            ],
          );

          try {
            final repo = container.read(transactionRepositoryProvider);
            await repo.addTransaction(
              _uid,
              Transaction(
                id: 'txn_fail',
                amount: 10000,
                currency: 'USD',
                type: 'expense',
                categoryId: 'cat_food',
                date: DateTime(2026, 1, 15),
                rateAtEntry: 280050,
                createdAt: DateTime(2026, 1, 15),
              ),
            );
            fail('Expected exception to be thrown');
          } on Exception catch (e) {
            expect(
              e.toString(),
              contains('Simulated transaction write failure'),
            );
          }
        },
      );

      test('REAL repository re-throws Firestore write failure instead of swallowing', () async {
        final mockFirestore = FakeFirebaseFirestore(
          securityRules: '''
              service cloud.firestore {
                match /databases/{database}/documents {
                  match /users/{uid}/wallets/{currency} {
                    allow read, write: if true;
                  }
                  match /users/{uid}/transactions/{id} {
                    allow read: if true;
                    allow write: if false;
                  }
                }
              }
            ''',
        );
        await _seedWallets(mockFirestore, _uid);

        final repo = TransactionRepository(mockFirestore);

        expect(
          () => repo.addTransaction(
            _uid,
            Transaction(
              id: 'txn_fail',
              amount: 10000,
              currency: 'USD',
              type: 'expense',
              categoryId: 'cat_food',
              date: DateTime(2026, 1, 15),
              rateAtEntry: 280050,
              createdAt: DateTime(2026, 1, 15),
            ),
          ),
          throwsException,
        );
      });
    });
  });
}

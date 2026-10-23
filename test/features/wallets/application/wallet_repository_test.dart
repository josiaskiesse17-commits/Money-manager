import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';

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

void main() {
  group('WalletRepository error propagation', () {
    test(
      'adjustBalance succeeds and updates both balance and openingBalance',
      () async {
        final mockFirestore = FakeFirebaseFirestore();
        await _seedWallets(mockFirestore, _uid);

        final repo = WalletRepository(mockFirestore);
        await repo.adjustBalance(_uid, 'USD', -500);

        final doc = await mockFirestore
            .collection('users')
            .doc(_uid)
            .collection('wallets')
            .doc('USD')
            .get();
        expect(doc.data()!['balance'], 9500);
        expect(doc.data()!['openingBalance'], 9500);
      },
    );

    test('updateBalance re-throws on Firestore write failure '
        '(not swallowed)', () async {
      // No wallet doc seeded — doc.update() throws FirebaseException (not-found).
      // The repository must re-throw so the caller can surface the error
      // rather than silently swallowing it (the original HEAD bug).
      final mockFirestore = FakeFirebaseFirestore();
      final repo = WalletRepository(mockFirestore);

      expect(() => repo.updateBalance(_uid, 'USD', -500), throwsException);
    });

    test('adjustBalance re-throws on Firestore write failure '
        '(not swallowed)', () async {
      // Security rules reject all writes to wallet docs. batch.commit()
      // throws during the set() call inside MockWriteBatch.commit().
      final mockFirestore = FakeFirebaseFirestore(
        securityRules: '''
          service cloud.firestore {
            match /databases/{database}/documents {
              match /users/{uid}/wallets/{currency} {
                allow read: if true;
                allow write: if false;
              }
            }
          }
        ''',
      );

      final repo = WalletRepository(mockFirestore);

      expect(() => repo.adjustBalance(_uid, 'USD', -500), throwsException);
    });
  });
}

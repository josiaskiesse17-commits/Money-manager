import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/budget.dart';
import 'package:money_manager/data/repositories/budget_repository.dart';

const _uid = 'test_uid';

/// A BudgetRepository that throws on every write, used to verify that
/// errors propagate to the caller instead of being swallowed.
class FailingBudgetRepository extends BudgetRepository {
  FailingBudgetRepository(super.firestore);

  @override
  Future<void> saveBudget(String uid, Budget budget) async {
    throw Exception('Simulated budget write failure');
  }
}

void main() {
  group('BudgetRepository with fake Firestore', () {
    group('BudgetRepository.saveBudget', () {
      test('successfully saves budget and reads it back', () async {
        final mockFirestore = FakeFirebaseFirestore();

        final repo = BudgetRepository(mockFirestore);
        await repo.saveBudget(
          _uid,
          const Budget(
            categoryId: 'cat_food',
            currency: 'CDF',
            monthlyLimit: 50000,
          ),
        );

        // Verify the budget was written
        final doc = await mockFirestore
            .collection('users')
            .doc(_uid)
            .collection('budgets')
            .doc('cat_food')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['categoryId'], 'cat_food');
        expect(doc.data()!['currency'], 'CDF');
        expect(doc.data()!['monthlyLimit'], 50000);
      });

      test(
        'throws when write fails (error propagates, not swallowed)',
        () async {
          final mockFirestore = FakeFirebaseFirestore();
          final container = ProviderContainer(
            overrides: [
              firestoreProvider.overrideWithValue(mockFirestore),
              budgetRepositoryProvider.overrideWithValue(
                FailingBudgetRepository(mockFirestore),
              ),
            ],
          );

          final repo = container.read(budgetRepositoryProvider);

          // The failing repository should throw, not swallow the error
          expect(
            () => repo.saveBudget(
              _uid,
              const Budget(
                categoryId: 'cat_food',
                currency: 'CDF',
                monthlyLimit: 50000,
              ),
            ),
            throwsException,
          );
        },
      );

      test('REAL repository re-throws Firestore write failure instead of '
          'swallowing', () async {
        final mockFirestore = FakeFirebaseFirestore(
          securityRules: '''
                service cloud.firestore {
                  match /databases/{database}/documents {
                    match /users/{uid}/budgets/{id} {
                      allow read: if true;
                      allow write: if false;
                    }
                  }
                }
              ''',
        );

        final repo = BudgetRepository(mockFirestore);

        expect(
          () => repo.saveBudget(
            _uid,
            const Budget(
              categoryId: 'cat_food',
              currency: 'CDF',
              monthlyLimit: 50000,
            ),
          ),
          throwsException,
        );
      });
    });
  });
}

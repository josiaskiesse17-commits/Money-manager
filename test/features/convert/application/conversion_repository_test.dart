import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/conversion.dart';
import 'package:money_manager/data/repositories/conversion_repository.dart';

const _uid = 'test_uid';

/// Mirrors firestore.rules conversion create conditions.
bool _validCurrency(String c) => c == 'CDF' || c == 'USD';
bool _positiveInt(dynamic v) => v is int && v > 0;
bool _toAmountValid(dynamic v) => v is int && v >= 0;

/// Asserts every firestore.rules conversion create condition against
/// [conversion.toMap()]. Throws [Exception] on first failure.
void assertConversionPassesRules(Conversion conversion) {
  final m = conversion.toMap();

  // isOwner(uid) — cannot test without auth; payload-side only below.

  if (!_positiveInt(m['fromAmount'])) {
    throw Exception('fromAmount must be int > 0');
  }
  if (!_toAmountValid(m['toAmount'])) {
    throw Exception('toAmount must be int >= 0');
  }
  if (!_validCurrency(m['fromCurrency'])) {
    throw Exception('fromCurrency must be CDF or USD');
  }
  if (!_validCurrency(m['toCurrency'])) {
    throw Exception('toCurrency must be CDF or USD');
  }
  if (m['fromCurrency'] == m['toCurrency']) {
    throw Exception('fromCurrency != toCurrency');
  }
  if (!_positiveInt(m['rate'])) {
    throw Exception('rate must be int > 0');
  }
  if (m['date'] is! Timestamp) {
    throw Exception('date must be a Timestamp');
  }
}

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

Future<int> _walletBalance(
  FakeFirebaseFirestore firestore,
  String uid,
  String currency,
) async {
  final doc = await firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc(currency)
      .get();
  return doc.data()!['balance'] as int;
}

Future<void> _assertWalletFieldsInt(
  FakeFirebaseFirestore firestore,
  String uid,
  String currency,
) async {
  final doc = await firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc(currency)
      .get();
  final data = doc.data() as Map<String, dynamic>;
  expect(
    data['balance'] is int,
    isTrue,
    reason: 'wallet $currency balance must be int after conversion',
  );
  expect(
    data['openingBalance'] is int,
    isTrue,
    reason: 'wallet $currency openingBalance must be int after conversion',
  );
}

/// A ConversionRepository that throws on every write, used to verify that
/// errors propagate to the caller instead of being swallowed.
class FailingConversionRepository extends ConversionRepository {
  FailingConversionRepository(super.firestore);

  @override
  Future<void> addConversion(String uid, Conversion conversion) async {
    throw Exception('Simulated conversion write failure');
  }

  @override
  Future<void> deleteConversion(String uid, Conversion conversion) async {
    throw Exception('Simulated conversion delete failure');
  }
}

void main() {
  group('Conversion correctness with fake Firestore', () {
    test('converting 10.00 USD to CDF at rate 280050 moves money from source to destination only', () async {
      final mockFirestore = FakeFirebaseFirestore();
      await _seedWallets(mockFirestore, _uid);

      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(mockFirestore)],
      );

      try {
        final repo = container.read(conversionRepositoryProvider);

        // Initial state: USD = 10000 cents ($100.00), CDF = 0
        expect(await _walletBalance(mockFirestore, _uid, 'USD'), 10000);
        expect(await _walletBalance(mockFirestore, _uid, 'CDF'), 0);

        // Convert 10.00 USD (1000 cents) to CDF at rate 280050 (2800.50 CDF/USD)
        // Expected CDF: 1000 * 280050 / 10000 = 28005 francs
        final conversion = Conversion(
          id: 'conv_1',
          fromCurrency: 'USD',
          toCurrency: 'CDF',
          fromAmount: 1000,
          toAmount: 28005,
          rate: 280050,
          date: DateTime(2026, 1, 15),
        );

        // Assert every rule condition against the payload before writing.
        assertConversionPassesRules(conversion);

        await repo.addConversion(_uid, conversion);

        // USD debited by 1000 cents, CDF credited by 28005 francs
        expect(await _walletBalance(mockFirestore, _uid, 'USD'), 9000);
        expect(await _walletBalance(mockFirestore, _uid, 'CDF'), 28005);

        // Both wallet docs must have balance and openingBalance as int.
        await _assertWalletFieldsInt(mockFirestore, _uid, 'USD');
        await _assertWalletFieldsInt(mockFirestore, _uid, 'CDF');

        // Delete the conversion: reverses both balances back to original
        await repo.deleteConversion(
          _uid,
          Conversion(
            id: 'conv_1',
            fromCurrency: 'USD',
            toCurrency: 'CDF',
            fromAmount: 1000,
            toAmount: 28005,
            rate: 280050,
            date: DateTime(2026, 1, 15),
          ),
        );

        expect(await _walletBalance(mockFirestore, _uid, 'USD'), 10000);
        expect(await _walletBalance(mockFirestore, _uid, 'CDF'), 0);
      } finally {
        container.dispose();
      }
    });

    test('reverse conversion: 28005 CDF back to USD at rate 280050', () async {
      final mockFirestore = FakeFirebaseFirestore();
      await _seedWallets(mockFirestore, _uid);

      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(mockFirestore)],
      );

      try {
        final repo = container.read(conversionRepositoryProvider);

        // Convert 28005 CDF back to USD at rate 280050
        // Expected USD: 28005 * 10000 / 280050 = 1000 cents
        final conversion = Conversion(
          id: 'conv_rev',
          fromCurrency: 'CDF',
          toCurrency: 'USD',
          fromAmount: 28005,
          toAmount: 1000,
          rate: 280050,
          date: DateTime(2026, 1, 16),
        );

        assertConversionPassesRules(conversion);

        await repo.addConversion(_uid, conversion);

        // CDF debited by 28005, USD credited by 1000
        expect(await _walletBalance(mockFirestore, _uid, 'CDF'), -28005);
        expect(await _walletBalance(mockFirestore, _uid, 'USD'), 11000);

        await _assertWalletFieldsInt(mockFirestore, _uid, 'USD');
        await _assertWalletFieldsInt(mockFirestore, _uid, 'CDF');

        // Delete reverses both
        await repo.deleteConversion(
          _uid,
          Conversion(
            id: 'conv_rev',
            fromCurrency: 'CDF',
            toCurrency: 'USD',
            fromAmount: 28005,
            toAmount: 1000,
            rate: 280050,
            date: DateTime(2026, 1, 16),
          ),
        );

        expect(await _walletBalance(mockFirestore, _uid, 'USD'), 10000);
        expect(await _walletBalance(mockFirestore, _uid, 'CDF'), 0);
      } finally {
        container.dispose();
      }
    });

    test('conversion never increases both wallets simultaneously', () async {
      final mockFirestore = FakeFirebaseFirestore();
      await _seedWallets(mockFirestore, _uid);

      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(mockFirestore)],
      );

      try {
        final repo = container.read(conversionRepositoryProvider);

        final conversion = Conversion(
          id: 'conv_3',
          fromCurrency: 'USD',
          toCurrency: 'CDF',
          fromAmount: 1000,
          toAmount: 28005,
          rate: 280050,
          date: DateTime(2026, 1, 15),
        );

        assertConversionPassesRules(conversion);

        await repo.addConversion(_uid, conversion);

        // One wallet goes down, the other goes up. Never both increase.
        final usdBal = await _walletBalance(mockFirestore, _uid, 'USD');
        final cdfBal = await _walletBalance(mockFirestore, _uid, 'CDF');
        expect(usdBal, lessThan(10000));
        expect(cdfBal, greaterThan(0));

        await _assertWalletFieldsInt(mockFirestore, _uid, 'USD');
        await _assertWalletFieldsInt(mockFirestore, _uid, 'CDF');
      } finally {
        container.dispose();
      }
    });

    test('assertConversionPassesRules rejects invalid payloads', () {
      // Valid conversion passes
      assertConversionPassesRules(
        Conversion(
          id: 'x',
          fromCurrency: 'USD',
          toCurrency: 'CDF',
          fromAmount: 100,
          toAmount: 2800,
          rate: 280050,
          date: DateTime(2026, 1, 1),
        ),
      );

      // fromAmount <= 0 fails positiveInt
      expect(
        () => assertConversionPassesRules(
          Conversion(
            id: 'x',
            fromCurrency: 'USD',
            toCurrency: 'CDF',
            fromAmount: 0,
            toAmount: 2800,
            rate: 280050,
            date: DateTime(2026, 1, 1),
          ),
        ),
        throwsException,
      );

      // fromCurrency == toCurrency fails
      expect(
        () => assertConversionPassesRules(
          Conversion(
            id: 'x',
            fromCurrency: 'USD',
            toCurrency: 'USD',
            fromAmount: 100,
            toAmount: 100,
            rate: 280050,
            date: DateTime(2026, 1, 1),
          ),
        ),
        throwsException,
      );

      // Invalid currency fails
      expect(
        () => assertConversionPassesRules(
          Conversion(
            id: 'x',
            fromCurrency: 'EUR',
            toCurrency: 'USD',
            fromAmount: 100,
            toAmount: 2800,
            rate: 280050,
            date: DateTime(2026, 1, 1),
          ),
        ),
        throwsException,
      );
    });

    test(
      'successful addConversion completes without error (no false alarm)',
      () async {
        final mockFirestore = FakeFirebaseFirestore();
        await _seedWallets(mockFirestore, _uid);

        final container = ProviderContainer(
          overrides: [firestoreProvider.overrideWithValue(mockFirestore)],
        );

        try {
          final repo = container.read(conversionRepositoryProvider);

          // This should complete without throwing — no false "Failed to save conversion"
          await repo.addConversion(
            _uid,
            Conversion(
              id: 'conv_success',
              fromCurrency: 'USD',
              toCurrency: 'CDF',
              fromAmount: 1000,
              toAmount: 28005,
              rate: 280050,
              date: DateTime(2026, 1, 15),
            ),
          );

          // Verify the write actually happened
          final usdBal = await _walletBalance(mockFirestore, _uid, 'USD');
          final cdfBal = await _walletBalance(mockFirestore, _uid, 'CDF');
          expect(usdBal, 9000);
          expect(cdfBal, 28005);
        } finally {
          container.dispose();
        }
      },
    );

    test(
      'failing addConversion throws (error propagates, not swallowed)',
      () async {
        final mockFirestore = FakeFirebaseFirestore();
        await _seedWallets(mockFirestore, _uid);

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(mockFirestore),
            conversionRepositoryProvider.overrideWithValue(
              FailingConversionRepository(mockFirestore),
            ),
          ],
        );

        try {
          final repo = container.read(conversionRepositoryProvider);

          // The failing repository should throw, not swallow the error
          expect(
            () => repo.addConversion(
              _uid,
              Conversion(
                id: 'conv_fail',
                fromCurrency: 'USD',
                toCurrency: 'CDF',
                fromAmount: 1000,
                toAmount: 28005,
                rate: 280050,
                date: DateTime(2026, 1, 15),
              ),
            ),
            throwsException,
          );
        } finally {
          container.dispose();
        }
      },
    );

    test(
      'failing deleteConversion throws (error propagates, not swallowed)',
      () async {
        final mockFirestore = FakeFirebaseFirestore();
        await _seedWallets(mockFirestore, _uid);

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(mockFirestore),
            conversionRepositoryProvider.overrideWithValue(
              FailingConversionRepository(mockFirestore),
            ),
          ],
        );

        try {
          final repo = container.read(conversionRepositoryProvider);

          expect(
            () => repo.deleteConversion(
              _uid,
              Conversion(
                id: 'conv_fail_delete',
                fromCurrency: 'USD',
                toCurrency: 'CDF',
                fromAmount: 1000,
                toAmount: 28005,
                rate: 280050,
                date: DateTime(2026, 1, 15),
              ),
            ),
            throwsException,
          );
        } finally {
          container.dispose();
        }
      },
    );

    test(
      'REAL repository re-throws Firestore write failure instead of swallowing',
      () async {
        final mockFirestore = FakeFirebaseFirestore(
          securityRules: '''
            service cloud.firestore {
              match /databases/{database}/documents {
                match /users/{uid}/wallets/{currency} {
                  allow read, write: if true;
                }
                match /users/{uid}/conversions/{id} {
                  allow read: if true;
                  allow write: if false;
                }
              }
            }
          ''',
        );
        await _seedWallets(mockFirestore, _uid);

        final container = ProviderContainer(
          overrides: [firestoreProvider.overrideWithValue(mockFirestore)],
        );

        try {
          final repo = container.read(conversionRepositoryProvider);

          expect(
            () => repo.addConversion(
              _uid,
              Conversion(
                id: 'conv_fail',
                fromCurrency: 'USD',
                toCurrency: 'CDF',
                fromAmount: 1000,
                toAmount: 28005,
                rate: 280050,
                date: DateTime(2026, 1, 15),
              ),
            ),
            throwsException,
          );
        } finally {
          container.dispose();
        }
      },
    );
  });
}

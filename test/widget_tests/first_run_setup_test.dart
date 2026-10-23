import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/repositories/auth_repository.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/onboarding/presentation/first_run_setup.dart';

const _uid = 'test_uid';

class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository()
    : super(MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: _uid)));
}

class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier()
    : super(_StubAuthRepository(), WalletRepository(FakeFirebaseFirestore())) {
    state = MockUser(uid: _uid);
  }
}

List<Override> _signedInOverrides(FakeFirebaseFirestore mockFirestore) {
  return [
    authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
    walletRepositoryProvider.overrideWithValue(WalletRepository(mockFirestore)),
    authProvider.overrideWith((ref) => _FakeAuthNotifier()),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

void main() {
  group('FirstRunSetup stores amounts in minor units', () {
    testWidgets('USD 10 stores 1000 cents and CDF 10000 stores 10000 francs', (
      tester,
    ) async {
      final mockFirestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _signedInOverrides(mockFirestore),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const FirstRunSetup(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fields are ordered: rate, CDF balance, USD balance.
      final rateField = find.byType(TextField).at(0);
      final cdfField = find.byType(TextField).at(1);
      final usdField = find.byType(TextField).at(2);

      await tester.enterText(rateField, '2800.50');
      await tester.enterText(cdfField, '10000');
      await tester.enterText(usdField, '10');

      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();

      // The wallet/settings writes are fire-and-forget; pump until they land.
      final wallets = mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets');
      var usdDoc = await wallets.doc('USD').get();
      var cdfDoc = await wallets.doc('CDF').get();
      for (var i = 0; i < 100 && !(usdDoc.exists && cdfDoc.exists); i++) {
        await tester.pump(const Duration(milliseconds: 50));
        usdDoc = await wallets.doc('USD').get();
        cdfDoc = await wallets.doc('CDF').get();
      }

      expect(usdDoc.exists, isTrue);
      expect(cdfDoc.exists, isTrue);
      expect(usdDoc.data()!['balance'], 1000);
      expect(usdDoc.data()!['openingBalance'], 1000);
      expect(cdfDoc.data()!['balance'], 10000);
      expect(cdfDoc.data()!['openingBalance'], 10000);

      final settingsDocRef = mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main');
      var settings = await settingsDocRef.get();
      for (var i = 0; i < 100 && !settings.exists; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        settings = await settingsDocRef.get();
      }
      expect(settings.exists, isTrue);
      expect(settings.data()!['usdToCdfRate'], 280050);
    });

    testWidgets('invalid USD amount shows an error and writes nothing', (
      tester,
    ) async {
      final mockFirestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _signedInOverrides(mockFirestore),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const FirstRunSetup(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final usdField = find.byType(TextField).at(2);
      await tester.enterText(usdField, 'abc');

      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid USD amount'), findsOneWidget);

      final wallets = mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets');
      expect((await wallets.doc('USD').get()).exists, isFalse);
      expect((await wallets.doc('CDF').get()).exists, isFalse);
    });
  });
}

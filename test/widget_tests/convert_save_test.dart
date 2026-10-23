import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/convert/presentation/convert_screen.dart';

const _phoneSize = Size(600, 800);

/// Overrides that wire ConvertScreen to a real (fake-Firestore-backed)
/// repository so writes succeed and the conversion is recorded.
List<Override> _overrides(FakeFirebaseFirestore firestore) {
  final mockAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: 'test_uid'),
  );
  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

/// Seeds the fake Firestore with a Setting and both wallets.
Future<void> _seed(FakeFirebaseFirestore firestore, String uid) async {
  await firestore
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
  await firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc('USD')
      .set({'balance': 10000, 'openingBalance': 0, 'currency': 'USD'});
  await firestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc('CDF')
      .set({'balance': 2800500, 'openingBalance': 0, 'currency': 'CDF'});
}

Future<void> _pumpConvert(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(firestore),
      child: MaterialApp(
        theme: ThemeData.light(),
        home: MediaQuery(
          data: const MediaQueryData(size: _phoneSize),
          child: const Scaffold(body: ConvertScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ConvertScreen save (top-level route, no pop)', () {
    testWidgets(
      'successful conversion shows "Conversion saved." and no error',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await _seed(firestore, 'test_uid');
        await _pumpConvert(tester, firestore);

        // Enter "10" USD — the TextFormField has label 'USD'.
        await tester.enterText(find.byType(TextFormField), '10');
        await tester.pumpAndSettle();

        // Tap the Convert button (not the SectionHeader which also says 'Convert').
        await tester.tap(
          find.descendant(
            of: find.byType(PrimaryButton),
            matching: find.text('Convert'),
          ),
        );

        // Let the batch commit + future resolve.
        await tester.pumpAndSettle();

        // The bug: context.pop() threw GoError, caught by catch, showing a
        // false "Failed to save conversion" error banner.
        expect(find.text('Conversion saved.'), findsOneWidget);
        expect(find.byType(ErrorBanner), findsNothing);

        // The conversion was actually written to Firestore.
        final snap = await firestore
            .collection('users')
            .doc('test_uid')
            .collection('conversions')
            .get();
        expect(snap.docs, isNotEmpty);
        expect(snap.docs.first.data()['fromCurrency'], 'USD');
        expect(snap.docs.first.data()['toCurrency'], 'CDF');
      },
    );
  });
}

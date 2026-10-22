import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';
import 'package:money_manager/features/settings/presentation/widgets/wallet_adjust_section.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

const _uid = 'test_uid';

(MockFirebaseAuth, List<Override>) _signedInOverrides(
  FakeFirebaseFirestore mockFirestore,
) {
  final mockAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: _uid),
  );
  return (
    mockAuth,
    [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      firestoreProvider.overrideWithValue(mockFirestore),
    ],
  );
}

Future<void> _seedWallets(FakeFirebaseFirestore firestore) async {
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('wallets')
      .doc('USD')
      .set({'currency': 'USD', 'balance': 10, 'openingBalance': 10});
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('wallets')
      .doc('CDF')
      .set({'currency': 'CDF', 'balance': 2800500, 'openingBalance': 2800500});
}

Future<FakeFirebaseFirestore> _pumpSettingsScreen(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  Brightness brightness = Brightness.light,
}) async {
  final mockFirestore = FakeFirebaseFirestore();
  await _seedWallets(mockFirestore);
  final (_, overrides) = _signedInOverrides(mockFirestore);

  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: testTheme(brightness: brightness),
        darkTheme: testTheme(brightness: Brightness.dark),
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        // AppShell provides the Scaffold in the real app.
        home: const Scaffold(body: SettingsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return mockFirestore;
}

Future<void> _openUsdAdjustDialog(WidgetTester tester) async {
  // USD is the second "Adjust balance" button (CDF first, USD second).
  final buttons = find.widgetWithText(PrimaryButton, 'Adjust balance');
  expect(buttons, findsNWidgets(2));
  // The Wallets card sits below the fold on a phone, so scroll it into view.
  await tester.ensureVisible(buttons.last);
  await tester.pumpAndSettle();
  await tester.tap(buttons.last);
  await tester.pumpAndSettle();
}

Future<void> _enterBalanceAndSave(WidgetTester tester, String text) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Current balance (USD)',
  );
  expect(field, findsOneWidget);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  group('WalletAdjustSection adjust balance', () {
    testWidgets(
      'adjusting USD 0.10 to 10.00 sets balance 1000 and opening +990',
      (tester) async {
        final mockFirestore = await _pumpSettingsScreen(tester);

        await _openUsdAdjustDialog(tester);
        await _enterBalanceAndSave(tester, '10.00');

        final usdDoc = await mockFirestore
            .collection('users')
            .doc(_uid)
            .collection('wallets')
            .doc('USD')
            .get();
        expect(usdDoc.data()!['balance'], 1000);
        expect(usdDoc.data()!['openingBalance'], 1000);
      },
    );

    testWidgets('negative diff works', (tester) async {
      final mockFirestore = FakeFirebaseFirestore();
      await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets')
          .doc('USD')
          .set({'currency': 'USD', 'balance': 1000, 'openingBalance': 1000});
      await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets')
          .doc('CDF')
          .set({
            'currency': 'CDF',
            'balance': 2800500,
            'openingBalance': 2800500,
          });
      final (_, overrides) = _signedInOverrides(mockFirestore);

      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: testTheme(brightness: Brightness.light),
            // AppShell provides the Scaffold in the real app.
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openUsdAdjustDialog(tester);
      await _enterBalanceAndSave(tester, '5.00');

      final usdDoc = await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(usdDoc.data()!['balance'], 500);
      expect(usdDoc.data()!['openingBalance'], 500);
    });

    testWidgets('invalid input shows error and writes nothing', (tester) async {
      final mockFirestore = await _pumpSettingsScreen(tester);

      await _openUsdAdjustDialog(tester);
      await _enterBalanceAndSave(tester, 'abc');

      expect(find.text('Enter a valid USD amount'), findsOneWidget);

      final usdDoc = await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(usdDoc.data()!['balance'], 10);
    });

    testWidgets('empty input shows error and writes nothing', (tester) async {
      final mockFirestore = await _pumpSettingsScreen(tester);

      await _openUsdAdjustDialog(tester);
      await _enterBalanceAndSave(tester, '');

      expect(find.text('Enter a valid USD amount'), findsOneWidget);

      final usdDoc = await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(usdDoc.data()!['balance'], 10);
    });
  });

  group('WalletAdjustSection responsive rendering', () {
    for (final size in [const Size(360, 800), const Size(1280, 800)]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final themeLabel = brightness == Brightness.light ? 'light' : 'dark';

        testWidgets('renders $sizeLabel $themeLabel without overflow', (
          tester,
        ) async {
          await _pumpSettingsScreen(tester, size: size, brightness: brightness);

          expect(find.byType(SettingsScreen), findsOneWidget);

          // Scope the wallet labels to the Wallets card: the exchange-rate
          // card also renders a "CDF" label.
          final wallets = find.byType(WalletAdjustSection);
          expect(wallets, findsOneWidget);
          expect(
            find.descendant(of: wallets, matching: find.text('Wallets')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: wallets, matching: find.text('USD')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: wallets, matching: find.text('CDF')),
            findsOneWidget,
          );

          await tester.binding.setSurfaceSize(null);
        });
      }
    }
  });
}

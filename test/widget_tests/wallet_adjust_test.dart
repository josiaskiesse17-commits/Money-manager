import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/widgets/primary_button.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';
import 'package:money_manager/features/settings/presentation/widgets/wallet_adjust_section.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

const _uid = 'test_uid';

/// Records every [WalletRepository.adjustBalance] call so the tests can
/// assert the diff the dialog asked for.
class _RecordingWalletRepository extends WalletRepository {
  _RecordingWalletRepository(super.firestore);

  final List<({String currency, int diff})> adjustments = [];

  @override
  Future<void> adjustBalance(String uid, String currency, int diff) async {
    adjustments.add((currency: currency, diff: diff));
    await super.adjustBalance(uid, currency, diff);
  }
}

MockFirebaseAuth _signedInAuth() {
  return MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: _uid));
}

Future<void> _seedWallets(
  FakeFirebaseFirestore firestore, {
  required int usdBalance,
  required int cdfBalance,
}) async {
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('wallets')
      .doc('USD')
      .set({
        'currency': 'USD',
        'balance': usdBalance,
        'openingBalance': usdBalance,
      });
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('wallets')
      .doc('CDF')
      .set({
        'currency': 'CDF',
        'balance': cdfBalance,
        'openingBalance': cdfBalance,
      });
}

Future<
  ({FakeFirebaseFirestore firestore, _RecordingWalletRepository repository})
>
_pumpSettingsScreen(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  Brightness brightness = Brightness.light,
  int usdBalance = 2000,
  int cdfBalance = 20000,
}) async {
  final mockFirestore = FakeFirebaseFirestore();
  await _seedWallets(
    mockFirestore,
    usdBalance: usdBalance,
    cdfBalance: cdfBalance,
  );
  final repository = _RecordingWalletRepository(mockFirestore);

  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(_signedInAuth()),
        firestoreProvider.overrideWithValue(mockFirestore),
        walletRepositoryProvider.overrideWithValue(repository),
      ],
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
  return (firestore: mockFirestore, repository: repository);
}

/// Opens the adjust dialog of one wallet: index 0 is CDF, index 1 is USD.
Future<void> _openAdjustDialog(WidgetTester tester, int index) async {
  final buttons = find.widgetWithText(PrimaryButton, 'Adjust balance');
  expect(buttons, findsNWidgets(2));
  // The Wallets card sits below the fold on a phone, so scroll it into view.
  await tester.ensureVisible(buttons.at(index));
  await tester.pumpAndSettle();
  await tester.tap(buttons.at(index));
  await tester.pumpAndSettle();
}

Finder _balanceField(String currency) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Current balance ($currency)',
  );
}

String _prefilledText(WidgetTester tester, String currency) {
  final field = tester.widget<TextField>(_balanceField(currency));
  return field.controller!.text;
}

Future<void> _typeAndSave(
  WidgetTester tester,
  String currency,
  String text,
) async {
  final field = _balanceField(currency);
  expect(field, findsOneWidget);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
  await tester.pumpAndSettle();
}

Future<int> _walletBalance(
  FakeFirebaseFirestore firestore,
  String currency,
) async {
  final doc = await firestore
      .collection('users')
      .doc(_uid)
      .collection('wallets')
      .doc(currency)
      .get();
  return doc.data()!['balance'] as int;
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  group('WalletAdjustSection adjust balance', () {
    testWidgets(
      'adjusting USD 0.10 to 10.00 sets balance 1000 and opening +990',
      (tester) async {
        final result = await _pumpSettingsScreen(
          tester,
          usdBalance: 10,
          cdfBalance: 2800500,
        );

        await _openAdjustDialog(tester, 1);
        await _typeAndSave(tester, 'USD', '10.00');

        final usdDoc = await result.firestore
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
      final result = await _pumpSettingsScreen(
        tester,
        usdBalance: 1000,
        cdfBalance: 2800500,
      );

      await _openAdjustDialog(tester, 1);
      await _typeAndSave(tester, 'USD', '5.00');

      final usdDoc = await result.firestore
          .collection('users')
          .doc(_uid)
          .collection('wallets')
          .doc('USD')
          .get();
      expect(usdDoc.data()!['balance'], 500);
      expect(usdDoc.data()!['openingBalance'], 500);
    });

    testWidgets('invalid input shows error and writes nothing', (tester) async {
      final result = await _pumpSettingsScreen(tester);

      await _openAdjustDialog(tester, 1);
      await _typeAndSave(tester, 'USD', 'abc');

      expect(find.text('Enter a valid USD amount'), findsOneWidget);
      expect(result.repository.adjustments, isEmpty);
      expect(await _walletBalance(result.firestore, 'USD'), 2000);
    });

    testWidgets('empty input shows error and writes nothing', (tester) async {
      final result = await _pumpSettingsScreen(tester);

      await _openAdjustDialog(tester, 1);
      await _typeAndSave(tester, 'USD', '');

      expect(find.text('Enter a valid USD amount'), findsOneWidget);
      expect(result.repository.adjustments, isEmpty);
      expect(await _walletBalance(result.firestore, 'USD'), 2000);
    });
  });

  group('WalletAdjustSection dialog input', () {
    testWidgets('prefills a plain editable number for USD', (tester) async {
      await _pumpSettingsScreen(tester, usdBalance: 2000);

      await _openAdjustDialog(tester, 1);

      expect(_prefilledText(tester, 'USD'), '20.00');
    });

    testWidgets('prefills a plain editable number for CDF', (tester) async {
      await _pumpSettingsScreen(tester, cdfBalance: 20000);

      await _openAdjustDialog(tester, 0);

      expect(_prefilledText(tester, 'CDF'), '20000');
    });

    // The current USD balance is $20.00 (2000 cents).
    const usdCases = [
      ('10', -1000),
      ('10.5', -950),
      ('10.50', -950),
      ('0', -2000),
      ('-5', -2500),
    ];

    for (final (input, expectedDiff) in usdCases) {
      testWidgets('accepts USD "$input" and adjusts by $expectedDiff', (
        tester,
      ) async {
        final result = await _pumpSettingsScreen(tester, usdBalance: 2000);

        await _openAdjustDialog(tester, 1);
        await _typeAndSave(tester, 'USD', input);

        expect(result.repository.adjustments, hasLength(1));
        expect(result.repository.adjustments.single.currency, 'USD');
        expect(result.repository.adjustments.single.diff, expectedDiff);
        expect(
          await _walletBalance(result.firestore, 'USD'),
          2000 + expectedDiff,
        );
      });
    }

    // The current CDF balance is 20000 francs.
    const cdfCases = [('5000', -15000), ('0', -20000)];

    for (final (input, expectedDiff) in cdfCases) {
      testWidgets('accepts CDF "$input" and adjusts by $expectedDiff', (
        tester,
      ) async {
        final result = await _pumpSettingsScreen(tester, cdfBalance: 20000);

        await _openAdjustDialog(tester, 0);
        await _typeAndSave(tester, 'CDF', input);

        expect(result.repository.adjustments, hasLength(1));
        expect(result.repository.adjustments.single.currency, 'CDF');
        expect(result.repository.adjustments.single.diff, expectedDiff);
        expect(
          await _walletBalance(result.firestore, 'CDF'),
          20000 + expectedDiff,
        );
      });
    }

    testWidgets('accepts a USD amount written with a comma decimal', (
      tester,
    ) async {
      final result = await _pumpSettingsScreen(tester, usdBalance: 2000);

      await _openAdjustDialog(tester, 1);
      await _typeAndSave(tester, 'USD', '10,50');

      expect(result.repository.adjustments, hasLength(1));
      expect(result.repository.adjustments.single.diff, -950);
    });

    testWidgets('shows an error for a non-numeric CDF amount', (tester) async {
      final result = await _pumpSettingsScreen(tester, cdfBalance: 20000);

      await _openAdjustDialog(tester, 0);
      await _typeAndSave(tester, 'CDF', 'abc');

      expect(
        find.text('Enter a valid whole-number CDF amount'),
        findsOneWidget,
      );
      expect(result.repository.adjustments, isEmpty);
      expect(await _walletBalance(result.firestore, 'CDF'), 20000);
    });

    testWidgets('shows an error for an empty CDF amount', (tester) async {
      final result = await _pumpSettingsScreen(tester, cdfBalance: 20000);

      await _openAdjustDialog(tester, 0);
      await _typeAndSave(tester, 'CDF', '');

      expect(
        find.text('Enter a valid whole-number CDF amount'),
        findsOneWidget,
      );
      expect(result.repository.adjustments, isEmpty);
      expect(await _walletBalance(result.firestore, 'CDF'), 20000);
    });

    testWidgets('keeps the current balance without writing when unchanged', (
      tester,
    ) async {
      final result = await _pumpSettingsScreen(tester, usdBalance: 2000);

      await _openAdjustDialog(tester, 1);
      // The prefilled value already is the current balance.
      expect(_prefilledText(tester, 'USD'), '20.00');
      await _typeAndSave(tester, 'USD', '20.00');

      expect(result.repository.adjustments, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await _walletBalance(result.firestore, 'USD'), 2000);
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/widgets/amount_text.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/charts/presentation/charts_screen.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

const _uid = 'test_uid';

const _phoneWidths = [320.0, 360.0, 411.0];
const _webWidth = 1280.0;
const _phoneHeight = 800.0;
const _textScales = [1.0, 1.3, 2.0];

const _longCategoryNames = [
  'Food',
  'Transport and communication',
  'Rent and housing',
  'Utilities and services',
  'Entertainment and hobbies',
  'Shopping and clothing',
  'Healthcare and insurance',
  'Education and training',
  'Savings and investments',
  'Other categories',
];

Future<void> _seedChartsData(
  FakeFirebaseFirestore firestore, {
  bool empty = false,
}) async {
  final user = firestore.collection('users').doc(_uid);

  await user.collection('settings').doc('main').set({
    'usdToCdfRate': 280050,
    'theme': 'light',
    'displayMode': 'combined',
    'onboarded': true,
  });

  await user.collection('wallets').doc('CDF').set({
    'currency': 'CDF',
    'openingBalance': 35000,
    'balance': 42000,
  });
  await user.collection('wallets').doc('USD').set({
    'currency': 'USD',
    'openingBalance': 10000,
    'balance': 15000,
  });

  for (var i = 0; i < _longCategoryNames.length; i++) {
    await user.collection('categories').doc('cat_$i').set({
      'name': _longCategoryNames[i],
      'icon': 'category',
      'color': 0xFF0F5FA8 + i * 5000,
      'type': 'expense',
      'archived': false,
    });
  }

  if (empty) {
    return;
  }

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 15);

  for (var i = 0; i < _longCategoryNames.length; i++) {
    await user.collection('transactions').doc('txn_$i').set({
      'amount': 50000 + i * 10000,
      'currency': 'USD',
      'type': 'expense',
      'categoryId': 'cat_$i',
      'date': Timestamp.fromDate(thisMonth),
      'note': 'Test transaction $i',
      'rateAtEntry': 280050,
      'createdAt': Timestamp.fromDate(thisMonth),
      'updatedAt': Timestamp.fromDate(thisMonth),
    });
  }
}

Future<List<Override>> _signedInOverrides({bool empty = false}) async {
  final firestore = FakeFirebaseFirestore();
  await _seedChartsData(firestore, empty: empty);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: _uid,
      email: 'test@example.com',
      isEmailVerified: true,
    ),
  );
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

Future<void> _pumpChartsScreen(
  WidgetTester tester, {
  required Size size,
  required List<Override> overrides,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final baseView = tester.view;
  final baseData = MediaQueryData.fromView(baseView);
  final adjustedData = baseData.copyWith(
    textScaler: TextScaler.linear(textScale),
  );

  await tester.pumpWidget(
    MediaQuery(
      data: adjustedData,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? testTheme()
              : testTheme(brightness: Brightness.dark),
          darkTheme: testTheme(brightness: Brightness.dark),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const ChartsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Returns true if the exception is a non-fatal sub-pixel overflow.
bool _isSubPixelOverflow(dynamic exception) {
  if (exception == null) return false;
  final message = exception.toString();
  final match = RegExp(r'overflowed by ([\d.]+) pixels?').firstMatch(message);
  return match != null && double.parse(match.group(1)!) < 2;
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  group('ChartsScreen layout with filled data', () {
    final widths = [..._phoneWidths, _webWidth];
    final brightnessValues = [Brightness.light, Brightness.dark];
    final textScales = _textScales;

    for (final width in widths) {
      for (final brightness in brightnessValues) {
        for (final textScale in textScales) {
          final screenName = width < 600 ? 'phone(${width.toInt()})' : 'web';
          final themeName = brightness == Brightness.light ? 'light' : 'dark';
          final label =
              'renders at $screenName $themeName scale${textScale}x with data';

          testWidgets(label, (tester) async {
            final size = Size(width, _phoneHeight);
            await _pumpChartsScreen(
              tester,
              size: size,
              overrides: await _signedInOverrides(),
              brightness: brightness,
              textScale: textScale,
            );

            final exception = tester.takeException();
            if (exception != null && !_isSubPixelOverflow(exception)) {
              fail('Widget rendered with exception: $exception');
            }
          });
        }
      }
    }
  });

  group('ChartsScreen empty state', () {
    for (final width in [..._phoneWidths, _webWidth]) {
      for (final textScale in _textScales) {
        final screenName = width < 600 ? 'phone' : 'web';
        final label =
            'renders empty at $screenName(${width.toInt()}) scale${textScale}x';

        testWidgets(label, (tester) async {
          final size = Size(width, _phoneHeight);
          await _pumpChartsScreen(
            tester,
            size: size,
            overrides: await _signedInOverrides(empty: true),
            textScale: textScale,
          );

          final exception = tester.takeException();
          if (exception != null && !_isSubPixelOverflow(exception)) {
            fail('Widget rendered with exception: $exception');
          }

          expect(find.text('No expenses this month'), findsOneWidget);
        });
      }
    }
  });

  group('ChartsScreen legend layout', () {
    testWidgets('legend appears below donut at phone width 360', (
      tester,
    ) async {
      await _pumpChartsScreen(
        tester,
        size: const Size(360, 800),
        overrides: await _signedInOverrides(),
      );

      expect(find.byType(DonutChart), findsOneWidget);
      // At phone width, DonutChart should have isWide=false (stacked layout)
      final donutWidget = tester.widget(find.byType(DonutChart)) as DonutChart;
      expect(donutWidget.isWide, false);

      // Legend AmountText should be present
      expect(find.byType(AmountText), findsWidgets);
    });

    testWidgets('legend appears beside donut at web width 1280', (
      tester,
    ) async {
      await _pumpChartsScreen(
        tester,
        size: const Size(1280, 800),
        overrides: await _signedInOverrides(),
      );

      expect(find.byType(DonutChart), findsOneWidget);
      // At web width, DonutChart should have isWide=true (side-by-side layout)
      final donutWidget = tester.widget(find.byType(DonutChart)) as DonutChart;
      expect(donutWidget.isWide, true);

      expect(find.byType(AmountText), findsWidgets);
    });
  });

  group('ChartsScreen content height', () {
    testWidgets('content at 360x800 with data renders without exception', (
      tester,
    ) async {
      await _pumpChartsScreen(
        tester,
        size: const Size(360, 800),
        overrides: await _signedInOverrides(),
        textScale: 2.0,
      );

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'Widget rendered with exception: $exception',
      );
    });
  });
}

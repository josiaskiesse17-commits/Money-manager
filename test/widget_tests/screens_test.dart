import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/presentation/sign_in_screen.dart';
import 'package:money_manager/features/auth/presentation/sign_up_screen.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';

const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

/// Helper: pump a screen and verify it renders without errors or overflow.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget widget,
  required Size size,
  required ThemeData theme,
  required List<Override> overrides,
}) async {
  final errors = <String>[];
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null &&
        (message.contains('overflowed') ||
            message.contains('No Material widget found') ||
            message.contains('assertion failed') ||
            message.contains('A RenderFlex overflowed'))) {
      errors.add(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  try {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: theme,
          darkTheme: AppTheme.dark(),
          themeMode: theme == ThemeData.light()
              ? ThemeMode.light
              : ThemeMode.dark,
          home: widget,
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    debugPrint = originalDebugPrint;
  }

  if (errors.isNotEmpty) {
    fail('Flutter errors detected:\n${errors.join('\n')}');
  }
}

/// Builds overrides for a signed-out scenario (auth screens).
List<Override> _signedOutOverrides() {
  final mockAuth = MockFirebaseAuth();
  final mockFirestore = FakeFirebaseFirestore();
  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

/// Builds overrides for a signed-in scenario (Home screen).
Future<List<Override>> _signedInOverrides({bool filledData = false}) async {
  final mockAuth = MockFirebaseAuth();
  final mockFirestore = FakeFirebaseFirestore();
  final uid = 'test_uid';

  // Pre-sign in the mock user
  await mockAuth.createUserWithEmailAndPassword(
    email: 'test@example.com',
    password: 'password123',
  );
  await mockAuth.signInWithEmailAndPassword(
    email: 'test@example.com',
    password: 'password123',
  );

  if (filledData) {
    // Seed Firestore so providers emit data instead of null/empty
    await mockFirestore
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
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('wallets')
        .doc('CDF')
        .set({'currency': 'CDF', 'openingBalance': 35000, 'balance': 42000});
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('wallets')
        .doc('USD')
        .set({'currency': 'USD', 'openingBalance': 10000, 'balance': 15000});
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc('cat_food')
        .set({
          'name': 'Food',
          'icon': 'restaurant',
          'color': 0xFFFF0000,
          'type': 'expense',
          'archived': false,
        });
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc('txn_1')
        .set({
          'amount': 123450,
          'currency': 'USD',
          'type': 'expense',
          'categoryId': 'cat_food',
          'date': Timestamp.fromDate(DateTime(2026, 1, 15)),
          'note': 'Groceries',
          'rateAtEntry': 280050,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        });
  }

  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

void main() {
  group('Widget rendering tests', () {
    for (final size in [_phoneSize, _webSize]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        final themeLabel = theme.brightness == Brightness.light
            ? 'light'
            : 'dark';

        testWidgets('HomeScreen $sizeLabel $themeLabel signed-out', (
          tester,
        ) async {
          await _pumpScreen(
            tester,
            widget: const HomeScreen(),
            size: size,
            theme: theme,
            overrides: _signedOutOverrides(),
          );
        });

        testWidgets('HomeScreen $sizeLabel $themeLabel signed-in empty', (
          tester,
        ) async {
          await _pumpScreen(
            tester,
            widget: const HomeScreen(),
            size: size,
            theme: theme,
            overrides: await _signedInOverrides(filledData: false),
          );
        });

        testWidgets('HomeScreen $sizeLabel $themeLabel signed-in filled', (
          tester,
        ) async {
          await _pumpScreen(
            tester,
            widget: const HomeScreen(),
            size: size,
            theme: theme,
            overrides: await _signedInOverrides(filledData: true),
          );
        });

        testWidgets('SignInScreen $sizeLabel $themeLabel', (tester) async {
          await _pumpScreen(
            tester,
            widget: const SignInScreen(),
            size: size,
            theme: theme,
            overrides: _signedOutOverrides(),
          );
        });

        testWidgets('SignUpScreen $sizeLabel $themeLabel', (tester) async {
          await _pumpScreen(
            tester,
            widget: const SignUpScreen(),
            size: size,
            theme: theme,
            overrides: _signedOutOverrides(),
          );
        });
      }
    }
  });
}

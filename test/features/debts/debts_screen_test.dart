import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/debts/presentation/debts_screen.dart';

const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

Future<List<Override>> _signedInOverrides({bool withDebts = false}) async {
  final uid = 'test_uid';
  final mockAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid),
  );
  final mockFirestore = FakeFirebaseFirestore();

  await mockAuth.createUserWithEmailAndPassword(
    email: 'test@example.com',
    password: 'password123',
  );
  await mockAuth.signInWithEmailAndPassword(
    email: 'test@example.com',
    password: 'password123',
  );

  // Seed wallets so balance increments never fail on a missing doc.
  await mockFirestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc('USD')
      .set({'currency': 'USD', 'openingBalance': 10000, 'balance': 10000});
  await mockFirestore
      .collection('users')
      .doc(uid)
      .collection('wallets')
      .doc('CDF')
      .set({'currency': 'CDF', 'openingBalance': 500000, 'balance': 500000});

  if (withDebts) {
    final now = DateTime(2026, 1, 1);
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('debts')
        .doc('debt_owe')
        .set({
          'name': 'Phone loan',
          'direction': 'owe',
          'currency': 'USD',
          'principal': 50000,
          'remaining': 30000,
          'archived': false,
          'createdAt': Timestamp.fromDate(now),
        });
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('debts')
        .doc('debt_owed')
        .set({
          'name': 'Personal loan',
          'direction': 'owed',
          'currency': 'CDF',
          'principal': 100000,
          'remaining': 100000,
          'dueDate': Timestamp.fromDate(DateTime(2026, 6, 1)),
          'archived': false,
          'createdAt': Timestamp.fromDate(now),
        });
    await mockFirestore
        .collection('users')
        .doc(uid)
        .collection('debts')
        .doc('debt_settled')
        .set({
          'name': 'Settled debt',
          'direction': 'owe',
          'currency': 'USD',
          'principal': 20000,
          'remaining': 0,
          'archived': false,
          'createdAt': Timestamp.fromDate(now),
        });
  }

  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

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

void main() {
  group('DebtsScreen', () {
    for (final size in [_phoneSize, _webSize]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        final themeLabel = theme.brightness == Brightness.light
            ? 'light'
            : 'dark';

        testWidgets('DebtsScreen $sizeLabel $themeLabel empty', (tester) async {
          await _pumpScreen(
            tester,
            widget: const DebtsScreen(),
            size: size,
            theme: theme,
            overrides: await _signedInOverrides(),
          );
        });

        testWidgets('DebtsScreen $sizeLabel $themeLabel with data', (
          tester,
        ) async {
          await _pumpScreen(
            tester,
            widget: const DebtsScreen(),
            size: size,
            theme: theme,
            overrides: await _signedInOverrides(withDebts: true),
          );
        });
      }
    }
  });
}

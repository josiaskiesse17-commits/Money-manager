import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/responsive_body.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/budgets/presentation/budgets_screen.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/transactions/presentation/transaction_list_screen.dart';

/// Layout tests: Home, Transactions and Budgets must render at phone
/// (360x800) and web (1280x800) sizes without any overflow or layout
/// exception, and [ResponsiveBody] must apply the design.md padding
/// (16 on phones, 24 on wide screens).
void main() {
  Future<List<Override>> signedInOverrides() async {
    final mockAuth = MockFirebaseAuth();
    final mockFirestore = FakeFirebaseFirestore();

    await mockAuth.createUserWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    );
    await mockAuth.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    );
    const uid = 'test_uid';

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
        .collection('budgets')
        .doc('cat_food')
        .set({
          'categoryId': 'cat_food',
          'currency': 'USD',
          'monthlyLimit': 50000,
        });
    // Current month so Home and Transactions include it.
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 15);
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
          'date': Timestamp.fromDate(thisMonth),
          'note': 'Groceries',
          'rateAtEntry': 280050,
          'createdAt': Timestamp.fromDate(thisMonth),
          'updatedAt': Timestamp.fromDate(thisMonth),
        });

    return [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      firestoreProvider.overrideWithValue(mockFirestore),
    ];
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Widget widget,
    required Size size,
    required List<Override> overrides,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: widget,
        ),
      ),
    );
    // Let async streams deliver data (avoid pumpAndSettle: the loading
    // spinner animates forever).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  const phone = Size(360, 800);
  const web = Size(1280, 800);
  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Transactions': const TransactionsScreen(),
    'Budgets': const BudgetsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders at 360x800 without overflow', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        widget: entry.value,
        size: phone,
        overrides: await signedInOverrides(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} renders at 1280x800 without overflow', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        widget: entry.value,
        size: web,
        overrides: await signedInOverrides(),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ResponsiveBody pads 16 on phones and 24 on wide screens', (
    tester,
  ) async {
    for (final entry in {phone: 16.0, web: 24.0}.entries) {
      tester.view.physicalSize = entry.key;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ResponsiveBody(child: const SizedBox()),
        ),
      );
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(ResponsiveBody),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, EdgeInsets.all(entry.value));
    }
  });
}

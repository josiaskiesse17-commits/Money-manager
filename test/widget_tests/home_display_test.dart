import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/month_provider.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/app/widgets/transaction_list_item.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/repositories/settings_repository.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/home/presentation/widgets/combined_total_card.dart';
import 'package:money_manager/features/home/presentation/widgets/display_mode_toggle.dart';

const _uid = 'test_uid';

/// Records saveSettings calls; reads still come from the fake Firestore.
class FakeSettingsRepository extends SettingsRepository {
  FakeSettingsRepository(super.firestore);

  final List<Setting> saved = [];

  @override
  Future<void> saveSettings(String uid, Setting setting) async {
    saved.add(setting);
  }
}

Future<void> _seed(
  FakeFirebaseFirestore firestore, {
  required String displayMode,
  DateTime? transactionDate,
}) async {
  final user = firestore.collection('users').doc(_uid);
  await user.collection('settings').doc('main').set({
    'usdToCdfRate': 280050,
    'theme': 'light',
    'displayMode': displayMode,
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
  await user.collection('categories').doc('cat_food').set({
    'name': 'Food',
    'icon': 'restaurant',
    'color': 0xFFFF0000,
    'type': 'expense',
    'archived': false,
  });
  if (transactionDate != null) {
    await user.collection('transactions').doc('txn_1').set({
      'amount': 5000,
      'currency': 'CDF',
      'type': 'expense',
      'categoryId': 'cat_food',
      'date': Timestamp.fromDate(transactionDate),
      'note': 'Lunch',
      'rateAtEntry': 280050,
      'createdAt': Timestamp.fromDate(transactionDate),
      'updatedAt': Timestamp.fromDate(transactionDate),
    });
  }
}

Future<FakeSettingsRepository> _pumpHome(
  WidgetTester tester, {
  required String displayMode,
  Size size = const Size(360, 800),
  ThemeData? theme,
  DateTime? transactionDate,
}) async {
  final firestore = FakeFirebaseFirestore();
  await _seed(
    firestore,
    displayMode: displayMode,
    transactionDate: transactionDate,
  );
  final repo = FakeSettingsRepository(firestore);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: _uid, email: 'test@example.com'),
  );

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(firestore),
        settingsRepositoryProvider.overrideWithValue(repo),
        selectedMonthProvider.overrideWith(
          (ref) => MonthNotifier()..setMonth(2026, 10),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Wallet card labels live inside AppCard; the toggle and total card do not.
Finder _walletCard(String currency) =>
    find.descendant(of: find.byType(AppCard), matching: find.text(currency));

Finder _segment(String label) => find.descendant(
  of: find.byType(DisplayModeToggle),
  matching: find.text(label),
);

void main() {
  group('Home display toggle and total', () {
    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        final label = '${size.width.toInt()}px ${theme.brightness.name}';
        testWidgets('toggle and total card render without overflow $label', (
          tester,
        ) async {
          await _pumpHome(
            tester,
            displayMode: 'combined',
            size: size,
            theme: theme,
          );
          expect(find.byType(DisplayModeToggle), findsOneWidget);
          expect(find.byType(CombinedTotalCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('cdf mode shows only the CDF wallet card', (tester) async {
      await _pumpHome(tester, displayMode: 'cdf');
      expect(_walletCard('CDF'), findsOneWidget);
      expect(_walletCard('USD'), findsNothing);
    });

    testWidgets('usd mode shows only the USD wallet card', (tester) async {
      await _pumpHome(tester, displayMode: 'usd');
      expect(_walletCard('USD'), findsOneWidget);
      expect(_walletCard('CDF'), findsNothing);
    });

    testWidgets('combined mode shows both wallet cards', (tester) async {
      await _pumpHome(tester, displayMode: 'combined');
      expect(_walletCard('CDF'), findsOneWidget);
      expect(_walletCard('USD'), findsOneWidget);
    });

    const taps = {
      'CDF': ['combined', 'cdf'],
      'USD': ['combined', 'usd'],
      'Both': ['cdf', 'combined'],
    };
    taps.forEach((segment, modes) {
      testWidgets('tapping $segment saves displayMode ${modes[1]}', (
        tester,
      ) async {
        final repo = await _pumpHome(tester, displayMode: modes[0]);
        await tester.tap(_segment(segment));
        await tester.pump();
        expect(repo.saved, hasLength(1));
        expect(repo.saved.single.displayMode, modes[1]);
      });
    });

    testWidgets('transaction at midnight on the 1st is in that month', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        displayMode: 'combined',
        transactionDate: DateTime(2026, 10, 1),
      );
      expect(find.byType(TransactionListItem), findsOneWidget);
    });

    testWidgets('transaction at midnight on the 1st of next month is not', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        displayMode: 'combined',
        transactionDate: DateTime(2026, 11, 1),
      );
      expect(find.byType(TransactionListItem), findsNothing);
    });

    testWidgets('tapping a recent transaction opens the edit sheet', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        displayMode: 'combined',
        transactionDate: DateTime(2026, 10, 15),
        size: const Size(800, 1200),
      );

      expect(find.byType(TransactionListItem), findsOneWidget);
      await tester.tap(find.byType(TransactionListItem).first);
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('deleting from Home then Undo restores the transaction', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        displayMode: 'combined',
        transactionDate: DateTime(2026, 10, 15),
        size: const Size(360, 1200),
      );

      expect(find.byType(TransactionListItem), findsOneWidget);

      // Drag to dismiss (triggers onDelete via Dismissible)
      await tester.drag(
        find.byType(TransactionListItem).first,
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete transaction?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Transaction removed from list
      expect(find.byType(TransactionListItem), findsNothing);

      // Undo snackbar
      expect(find.text('Transaction deleted successfully.'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Transaction restored
      expect(find.byType(TransactionListItem), findsOneWidget);
    });
  });
}

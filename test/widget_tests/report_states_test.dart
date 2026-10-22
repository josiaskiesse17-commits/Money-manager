import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/app/widgets/empty_state.dart';
import 'package:money_manager/app/widgets/error_banner.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/data/models/setting.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/models/wallet.dart';
import 'package:money_manager/data/repositories/category_repository.dart';
import 'package:money_manager/data/repositories/settings_repository.dart';
import 'package:money_manager/data/repositories/transaction_repository.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/features/reports/presentation/report_screen.dart';

const _phoneSize = Size(360, 800);

/// Scripted transaction repository: the test decides what (and when) the
/// stream emits, so the screen can be frozen in loading or error.
class _ScriptedTransactionRepository extends TransactionRepository {
  _ScriptedTransactionRepository(this._stream) : super(FakeFirebaseFirestore());
  final Stream<List<Transaction>> _stream;
  @override
  Stream<List<Transaction>> watchTransactions(String uid) => _stream;
}

/// Scripted category repository.
class _ScriptedCategoryRepository extends CategoryRepository {
  _ScriptedCategoryRepository(this._stream) : super(FakeFirebaseFirestore());
  final Stream<List<Category>> _stream;
  @override
  Stream<List<Category>> watchCategories(
    String uid, {
    bool includeArchived = false,
  }) => _stream;
}

/// Scripted settings repository.
class _ScriptedSettingsRepository extends SettingsRepository {
  _ScriptedSettingsRepository(this._stream) : super(FakeFirebaseFirestore());
  final Stream<Setting?> _stream;
  @override
  Stream<Setting?> watchSettings(String uid) => _stream;
}

/// Scripted wallet repository.
class _ScriptedWalletRepository extends WalletRepository {
  _ScriptedWalletRepository(this._stream) : super(FakeFirebaseFirestore());
  final Stream<List<Wallet>> _stream;
  @override
  Stream<List<Wallet>> watchWallets(String uid) => _stream;
}

/// A stream that never emits: simulates offline silence (not an error).
Stream<T> _silentStream<T>() {
  final controller = StreamController<T>.broadcast();
  return controller.stream;
}

/// Builds the overrides for one ReportScreen scenario.
///
/// [transactions] is the stream for the transaction repository; the other
/// three repositories always emit their data immediately.
List<Override> _overrides({
  required Stream<List<Transaction>> transactions,
  Stream<List<Category>>? categories,
  Stream<Setting?>? settings,
  Stream<List<Wallet>>? wallets,
}) {
  final mockAuth = MockFirebaseAuth();

  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    transactionRepositoryProvider.overrideWithValue(
      _ScriptedTransactionRepository(transactions),
    ),
    categoryRepositoryProvider.overrideWithValue(
      _ScriptedCategoryRepository(
        categories ?? Stream.value(const <Category>[]),
      ),
    ),
    settingsRepositoryProvider.overrideWithValue(
      _ScriptedSettingsRepository(
        settings ??
            Stream.value(
              const Setting(
                docId: 'main',
                usdToCdfRate: 280050,
                theme: 'light',
                displayMode: 'combined',
                onboarded: true,
              ),
            ),
      ),
    ),
    walletRepositoryProvider.overrideWithValue(
      _ScriptedWalletRepository(
        wallets ??
            Stream.value(const [
              Wallet(currency: 'CDF', openingBalance: 35000, balance: 42000),
              Wallet(currency: 'USD', openingBalance: 10000, balance: 15000),
            ]),
      ),
    ),
  ];
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light(), home: const ReportScreen()),
    ),
  );
}

void main() {
  group('ReportScreen states', () {
    testWidgets('shows a loading indicator while data is still loading', (
      tester,
    ) async {
      await _pumpReport(
        tester,
        overrides: _overrides(transactions: _silentStream()),
      );
      // pump() instead of pumpAndSettle(): CircularProgressIndicator animates
      // forever, which would keep pumpAndSettle from ever settling.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(ErrorBanner), findsNothing);

      // Silence is not an error: the screen stays in loading.
      await tester.pump(const Duration(seconds: 15));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(ErrorBanner), findsNothing);
    });

    testWidgets('shows an error banner with Retry when loading fails', (
      tester,
    ) async {
      await _pumpReport(
        tester,
        overrides: _overrides(
          transactions: Stream<List<Transaction>>.error(
            Exception('Permission denied'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Failed to load transactions.'), findsOneWidget);
    });

    testWidgets('shows an error banner when categories fail to load', (
      tester,
    ) async {
      await _pumpReport(
        tester,
        overrides: _overrides(
          transactions: Stream.value(const <Transaction>[]),
          categories: Stream<List<Category>>.error(
            Exception('Permission denied'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('Failed to load categories.'), findsOneWidget);
    });

    testWidgets('retry reloads the failed source without throwing', (
      tester,
    ) async {
      await _pumpReport(
        tester,
        overrides: _overrides(
          transactions: Stream<List<Transaction>>.error(
            Exception('Permission denied'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ErrorBanner), findsOneWidget);

      // Pressing Retry rebuilds the provider; the scripted repository keeps
      // erroring, so the banner stays — the button must at least be tappable
      // and must not throw.
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty state when the period has no transactions', (
      tester,
    ) async {
      await _pumpReport(
        tester,
        overrides: _overrides(
          transactions: Stream.value(const <Transaction>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No transactions in this period'), findsOneWidget);
      expect(find.byType(ErrorBanner), findsNothing);
    });

    testWidgets('shows the preview without an empty state when data exists', (
      tester,
    ) async {
      final now = DateTime.now();
      await _pumpReport(
        tester,
        overrides: _overrides(
          transactions: Stream.value([
            Transaction(
              id: 'txn_1',
              amount: 123450,
              currency: 'USD',
              type: 'expense',
              categoryId: 'cat_food',
              date: now,
              note: 'Groceries',
              rateAtEntry: 280050,
              createdAt: now,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(ErrorBanner), findsNothing);
      expect(find.text('Generate PDF'), findsOneWidget);
    });

    testWidgets('renders at phone and web width in light and dark', (
      tester,
    ) async {
      for (final size in [const Size(360, 800), const Size(1280, 800)]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          final errors = <String>[];
          final originalDebugPrint = debugPrint;
          debugPrint = (String? message, {int? wrapWidth}) {
            if (message != null && message.contains('overflowed')) {
              errors.add(message);
            }
            originalDebugPrint(message, wrapWidth: wrapWidth);
          };

          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: _overrides(
                transactions: Stream.value(const <Transaction>[]),
              ),
              child: MaterialApp(
                theme: brightness == Brightness.light
                    ? AppTheme.light()
                    : AppTheme.dark(),
                home: const ReportScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          debugPrint = originalDebugPrint;

          expect(
            errors,
            isEmpty,
            reason: 'overflow at $size in $brightness: ${errors.join(' | ')}',
          );
          expect(find.byType(EmptyState), findsOneWidget);
        }
      }

      await tester.binding.setSurfaceSize(null);
    });
  });
}

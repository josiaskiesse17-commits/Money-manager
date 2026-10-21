import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/transaction.dart';
import 'package:money_manager/data/repositories/transaction_repository.dart';
import 'package:money_manager/features/charts/presentation/charts_screen.dart';

const _phoneSize = Size(360, 800);

class _ScriptedTxnRepository extends TransactionRepository {
  _ScriptedTxnRepository(this._stream) : super(FakeFirebaseFirestore());
  final Stream<List<Transaction>> _stream;
  @override
  Stream<List<Transaction>> watchTransactions(String uid) => _stream;
}

Stream<List<Transaction>> silentStream() {
  final controller = StreamController<List<Transaction>>.broadcast();
  return controller.stream;
}

Future<void> _signIn(MockFirebaseAuth auth) async {
  await auth.createUserWithEmailAndPassword(
    email: 'test@example.com',
    password: 'password123',
  );
  await auth.signInWithEmailAndPassword(
    email: 'test@example.com',
    password: 'password123',
  );
}

void main() {
  group('ChartsScreen loading states', () {
    testWidgets('silent transaction stream keeps loading indicator', (
      tester,
    ) async {
      final mockAuth = MockFirebaseAuth();
      await _signIn(mockAuth);

      await tester.binding.setSurfaceSize(_phoneSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockAuth),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            transactionRepositoryProvider.overrideWithValue(
              _ScriptedTxnRepository(silentStream()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ChartsScreen(),
          ),
        ),
      );
      // pump() instead of pumpAndSettle(): CircularProgressIndicator animates
      // forever, which would keep pumpAndSettle from ever settling.
      await tester.pump(const Duration(milliseconds: 100));

      // Loading indicator visible during offline silence (not an error).
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('empty transaction stream shows empty state', (tester) async {
      final mockAuth = MockFirebaseAuth();
      await _signIn(mockAuth);

      await tester.binding.setSurfaceSize(_phoneSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockAuth),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ChartsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No expenses this month'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });
  });
}

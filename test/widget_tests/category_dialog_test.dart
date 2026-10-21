import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/models/category.dart';
import 'package:money_manager/features/settings/presentation/category_dialog.dart';

const _phoneSize = Size(360, 800);

/// Returns a signed-in-ready [MockFirebaseAuth] plus overrides that use it.
(MockFirebaseAuth, List<Override>) _signedInOverrides({
  FakeFirebaseFirestore? firestore,
}) {
  final mockAuth = MockFirebaseAuth();
  final mockFirestore = firestore ?? FakeFirebaseFirestore();
  return (
    mockAuth,
    [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      firestoreProvider.overrideWithValue(mockFirestore),
    ],
  );
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

/// Pumps a [CategoryDialog] directly as the home so it renders reliably.
Future<void> _pumpDialog(
  WidgetTester tester, {
  required Widget dialog,
  required List<Override> overrides,
}) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Center(child: dialog),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('CategoryDialog', () {
    testWidgets('renders add mode without overflow', (tester) async {
      final (auth, overrides) = _signedInOverrides();
      await _signIn(auth);

      await _pumpDialog(
        tester,
        dialog: const CategoryDialog(),
        overrides: overrides,
      );

      expect(find.byType(CategoryDialog), findsOneWidget);
      expect(find.text('Add category'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders edit mode prepopulated', (tester) async {
      final (auth, overrides) = _signedInOverrides();
      await _signIn(auth);

      final existing = const Category(
        id: 'cat_food',
        name: 'Food',
        icon: 'category',
        color: 0xFFC73E2E,
        type: 'expense',
        archived: false,
      );

      await _pumpDialog(
        tester,
        dialog: CategoryDialog(category: existing),
        overrides: overrides,
      );

      expect(find.byType(CategoryDialog), findsOneWidget);
      expect(find.text('Edit category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets(
      'save with empty name shows validation error and does not close',
      (tester) async {
        final (auth, overrides) = _signedInOverrides();
        await _signIn(auth);

        await _pumpDialog(
          tester,
          dialog: const CategoryDialog(),
          overrides: overrides,
        );

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Validation error shown, dialog stays open.
        expect(find.text('Enter a category name'), findsOneWidget);
        expect(find.byType(CategoryDialog), findsOneWidget);
      },
    );
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';

const _uid = 'test_uid';

List<Override> _signedInOverrides(FakeFirebaseFirestore mockFirestore) {
  final mockAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: _uid),
  );
  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

void main() {
  group('Settings exchange rate field uses Money.parse', () {
    testWidgets('typing 2800.50 saves rate 280050', (tester) async {
      final mockFirestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _signedInOverrides(mockFirestore),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rateField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'CDF per 1 USD',
      );
      await tester.enterText(rateField, '2800.50');
      await tester.tap(find.text('Save exchange rate'));
      await tester.pumpAndSettle();

      final settings = await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main')
          .get();
      expect(settings.data()!['usdToCdfRate'], 280050);
    });

    testWidgets('invalid rate shows an error and writes nothing', (
      tester,
    ) async {
      final mockFirestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _signedInOverrides(mockFirestore),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rateField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'CDF per 1 USD',
      );
      await tester.enterText(rateField, 'abc');
      await tester.tap(find.text('Save exchange rate'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid exchange rate greater than zero.'),
        findsOneWidget,
      );

      final settings = await mockFirestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main')
          .get();
      expect(settings.exists, isFalse);
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/presentation/verify_email_screen.dart';

const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

Future<List<Override>> _signedInUnverifiedOverrides() async {
  final mockAuth = MockFirebaseAuth(verifyEmailAutomatically: false);
  final mockFirestore = FakeFirebaseFirestore();
  await mockAuth.createUserWithEmailAndPassword(
    email: 'unverified@example.com',
    password: 'password123',
  );
  await mockAuth.signInWithEmailAndPassword(
    email: 'unverified@example.com',
    password: 'password123',
  );

  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

void main() {
  group('VerifyEmailScreen', () {
    for (final size in [_phoneSize, _webSize]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        final themeLabel = theme.brightness == Brightness.light
            ? 'light'
            : 'dark';

        testWidgets('renders $sizeLabel $themeLabel without overflow', (
          tester,
        ) async {
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
                overrides: await _signedInUnverifiedOverrides(),
                child: MaterialApp(
                  theme: theme,
                  darkTheme: AppTheme.dark(),
                  themeMode: theme == ThemeData.light()
                      ? ThemeMode.light
                      : ThemeMode.dark,
                  home: const VerifyEmailScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();
          } finally {
            debugPrint = originalDebugPrint;
            await tester.binding.setSurfaceSize(null);
          }

          if (errors.isNotEmpty) {
            fail('Flutter errors detected:\n${errors.join('\n')}');
          }

          expect(find.text('Verify your email'), findsOneWidget);
          expect(find.textContaining('unverified@example.com'), findsOneWidget);
          expect(find.text('Resend verification email'), findsOneWidget);
          expect(find.text('Check again'), findsOneWidget);
          expect(find.text('Sign out'), findsOneWidget);
        });

        testWidgets('resend shows a visible cooldown $sizeLabel $themeLabel', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: await _signedInUnverifiedOverrides(),
              child: MaterialApp(
                theme: theme,
                darkTheme: AppTheme.dark(),
                themeMode: theme == ThemeData.light()
                    ? ThemeMode.light
                    : ThemeMode.dark,
                home: const VerifyEmailScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Resend verification email'), findsOneWidget);
          expect(find.textContaining('Resend again in'), findsNothing);

          await tester.tap(find.text('Resend verification email').first);
          await tester.pumpAndSettle();

          // During the cooldown a countdown is shown, preventing repeated taps.
          expect(find.textContaining('Resend again in'), findsOneWidget);

          await tester.binding.setSurfaceSize(null);
        });

        testWidgets('sign out button is present $sizeLabel $themeLabel', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: await _signedInUnverifiedOverrides(),
              child: MaterialApp(
                theme: theme,
                darkTheme: AppTheme.dark(),
                themeMode: theme == ThemeData.light()
                    ? ThemeMode.light
                    : ThemeMode.dark,
                home: const VerifyEmailScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Sign out'), findsOneWidget);

          await tester.binding.setSurfaceSize(null);
        });
      }
    }
  });
}

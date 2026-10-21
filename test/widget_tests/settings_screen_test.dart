import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/theme.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/auth/presentation/sign_in_screen.dart';
import 'package:money_manager/features/settings/presentation/category_dialog.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';

const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

/// Returns a signed-in-ready [MockFirebaseAuth] plus overrides that use it.
(MockFirebaseAuth, List<Override>) _signedInOverrides() {
  final mockAuth = MockFirebaseAuth();
  final mockFirestore = FakeFirebaseFirestore();
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

GoRouter _settingsRouter() => GoRouter(
  initialLocation: AppRoutes.settings,
  routes: [
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
  ],
);

void main() {
  group('SettingsScreen', () {
    for (final size in [_phoneSize, _webSize]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        final themeLabel = theme.brightness == Brightness.light
            ? 'light'
            : 'dark';

        testWidgets('renders $sizeLabel $themeLabel without overflow', (
          tester,
        ) async {
          final (auth, overrides) = _signedInOverrides();
          await _signIn(auth);

          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: MaterialApp.router(
                theme: theme,
                darkTheme: AppTheme.dark(),
                themeMode: theme == ThemeData.light()
                    ? ThemeMode.light
                    : ThemeMode.dark,
                routerConfig: _settingsRouter(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(find.text('Settings'), findsOneWidget);
          expect(find.text('Sign out'), findsOneWidget);
          expect(find.text('Add category'), findsOneWidget);

          await tester.binding.setSurfaceSize(null);
        });

        testWidgets('signing out signs the user out and navigates to sign in '
            '$sizeLabel $themeLabel', (tester) async {
          final (auth, overrides) = _signedInOverrides();
          await _signIn(auth);
          expect(auth.currentUser, isNotNull);

          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: MaterialApp.router(
                theme: theme,
                darkTheme: AppTheme.dark(),
                themeMode: theme == ThemeData.light()
                    ? ThemeMode.light
                    : ThemeMode.dark,
                routerConfig: _settingsRouter(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Scroll to reveal the Sign out button at the bottom of the form.
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Sign out'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 200));

          expect(auth.currentUser, isNull);
          expect(find.byType(SignInScreen), findsOneWidget);

          await tester.binding.setSurfaceSize(null);
        });

        testWidgets('tapping Add category opens the category dialog '
            '$sizeLabel $themeLabel', (tester) async {
          final (auth, overrides) = _signedInOverrides();
          await _signIn(auth);

          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: MaterialApp.router(
                theme: theme,
                darkTheme: AppTheme.dark(),
                themeMode: theme == ThemeData.light()
                    ? ThemeMode.light
                    : ThemeMode.dark,
                routerConfig: _settingsRouter(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Add category').first);
          await tester.pumpAndSettle();

          expect(find.byType(CategoryDialog), findsOneWidget);

          await tester.binding.setSurfaceSize(null);
        });
      }
    }
  });
}

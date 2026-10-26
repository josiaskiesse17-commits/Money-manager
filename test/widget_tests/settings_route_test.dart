import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/auth_gate.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/app/router.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/data/repositories/auth_repository.dart';
import 'package:money_manager/data/repositories/wallet_repository.dart';
import 'package:money_manager/features/auth/application/auth_provider.dart';
import 'package:money_manager/features/home/presentation/home_screen.dart';
import 'package:money_manager/features/reports/presentation/report_screen.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

const _uid = 'test_uid';

/// A fake [AuthStateNotifier] that starts with the given user already signed in.
class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(MockUser user)
    : super(
        AuthRepository(MockFirebaseAuth(signedIn: true, mockUser: user)),
        WalletRepository(FakeFirebaseFirestore()),
      );
}

/// Simple app widget that uses the overridden [routerProvider].
class _TestRouterApp extends ConsumerWidget {
  const _TestRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      theme: testTheme(),
    );
  }
}

/// Builds a router that checks auth via the provided [mockAuth].
GoRouter _makeRouter(Ref ref, MockFirebaseAuth mockAuth) {
  const openRoutes = <String>{
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.resetPassword,
  };

  return GoRouter(
    initialLocation: AppRoutes.signIn,
    redirect: (context, state) {
      final user = mockAuth.currentUser;
      final isOpen = openRoutes.contains(state.matchedLocation);

      if (user == null) {
        return isOpen ? null : AppRoutes.signIn;
      }

      if (!user.emailVerified) {
        return isOpen ? null : AppRoutes.signIn;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const AuthGate()),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) =>
            AppShell(currentRoute: AppRoutes.home, child: const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, _) => AppShell(
          currentRoute: AppRoutes.reports,
          child: const ReportScreen(),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  Future<List<Override>> signedInOverrides(
    MockFirebaseAuth mockAuth,
    FakeFirebaseFirestore mockFirestore,
  ) async {
    await mockFirestore
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('main')
        .set({
          'usdToCdfRate': 280050,
          'theme': 'light',
          'displayMode': 'combined',
          'onboarded': true,
        });

    final user = mockAuth.currentUser as MockUser;
    return [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      firestoreProvider.overrideWithValue(mockFirestore),
      authProvider.overrideWith((ref) => _FakeAuthNotifier(user)),
      routerProvider.overrideWith((ref) => _makeRouter(ref, mockAuth)),
    ];
  }

  group('Settings route: standalone route + Reports link', () {
    for (final size in [_phoneSize, _webSize]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';

      testWidgets('SettingsScreen renders alone at $sizeLabel', (tester) async {
        final user = MockUser(
          uid: _uid,
          email: 'test@example.com',
          isEmailVerified: true,
        );
        final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
        final mockFirestore = FakeFirebaseFirestore();
        final overrides = await signedInOverrides(mockAuth, mockFirestore);

        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(overrides: overrides, child: const _TestRouterApp()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppShell), findsOneWidget);

        await tester.tap(find.byIcon(Icons.settings).first);
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.widgetList(find.byType(NavigationBar)).length, 0);
        expect(tester.widgetList(find.byType(NavigationRail)).length, 0);
        expect(tester.widgetList(find.byType(AppBar)).length, 1);
        expect(find.text('Settings'), findsOneWidget);

        await tester.binding.setSurfaceSize(null);
      });
    }

    testWidgets('Reports link in Settings navigates to ReportScreen', (
      tester,
    ) async {
      final user = MockUser(
        uid: _uid,
        email: 'test@example.com',
        isEmailVerified: true,
      );
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final mockFirestore = FakeFirebaseFirestore();
      final overrides = await signedInOverrides(mockAuth, mockFirestore);

      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(overrides: overrides, child: const _TestRouterApp()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pumpAndSettle();

      // Scroll to ensure Reports is visible before tapping
      await tester.ensureVisible(find.text('Reports').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reports').first);
      await tester.pumpAndSettle();

      expect(find.byType(ReportScreen), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}

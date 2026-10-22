import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/app_shell.dart';
import 'package:money_manager/app/routes.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/convert/presentation/convert_screen.dart';
import 'package:money_manager/features/reports/presentation/report_screen.dart';

const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

List<Override> _signedInOverrides() {
  final mockAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: 'test_uid'),
  );
  final mockFirestore = FakeFirebaseFirestore();
  return [
    firebaseAuthProvider.overrideWithValue(mockAuth),
    firestoreProvider.overrideWithValue(mockFirestore),
  ];
}

/// Pumps [child] inside [AppShell] at an explicit [size].
///
/// `tester.binding.setSurfaceSize` does not move [MediaQuery.sizeOf] in this
/// environment, so an explicit [MediaQuery] wrapper is used to make the shell
/// see the requested width.
Future<void> _pumpShell(
  WidgetTester tester, {
  required String route,
  required Widget child,
  required Size size,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _signedInOverrides(),
      child: MaterialApp(
        theme: ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: AppShell(currentRoute: route, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Navigation shell has exactly one navigation control', () {
    final cases = <MapEntry<String, Widget>>[
      MapEntry(AppRoutes.convert, const ConvertScreen()),
      MapEntry(AppRoutes.reports, const ReportScreen()),
    ];

    for (final size in [_phoneSize, _webSize]) {
      final isWide = size.width >= 840;
      for (final c in cases) {
        testWidgets('${c.key} at ${size.width}px shows exactly one '
            '${isWide ? 'NavigationRail' : 'NavigationBar'}', (tester) async {
          await _pumpShell(tester, route: c.key, child: c.value, size: size);

          if (isWide) {
            expect(find.byType(NavigationRail), findsOneWidget);
            expect(find.byType(NavigationBar), findsNothing);
          } else {
            expect(find.byType(NavigationBar), findsOneWidget);
            expect(find.byType(NavigationRail), findsNothing);
          }
        });
      }
    }
  });
}

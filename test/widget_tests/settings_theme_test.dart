import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/widgets/app_card.dart';
import 'package:money_manager/data/firebase_providers.dart';
import 'package:money_manager/features/settings/presentation/settings_screen.dart';

import '../helpers/test_fonts.dart';
import '../helpers/test_theme.dart';

const _uid = 'test_uid';
const _phoneSize = Size(360, 800);
const _webSize = Size(1280, 800);

List<Override> _overrides(FakeFirebaseFirestore firestore) {
  return [
    firebaseAuthProvider.overrideWithValue(
      MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: _uid)),
    ),
    firestoreProvider.overrideWithValue(firestore),
  ];
}

Finder _rateField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'CDF per 1 USD',
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
}) async {
  final mockFirestore = FakeFirebaseFirestore();

  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(mockFirestore),
      child: MaterialApp(
        theme: testTheme(brightness: brightness),
        darkTheme: testTheme(brightness: Brightness.dark),
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        // AppShell provides the Scaffold in the real app.
        home: const Scaffold(body: SettingsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  group('Settings screen theme and layout', () {
    for (final size in [_phoneSize, _webSize]) {
      final sizeLabel = size.width < 600 ? 'phone' : 'web';
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final themeLabel = brightness == Brightness.light ? 'light' : 'dark';

        testWidgets('renders $sizeLabel $themeLabel without overflow', (
          tester,
        ) async {
          await _pumpSettings(tester, size: size, brightness: brightness);

          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          // One card per section, each with its own header.
          expect(find.byType(AppCard), findsWidgets);
          for (final title in [
            'Settings',
            'Exchange rate',
            'Wallets',
            'Categories',
            'Appearance',
            'Security',
            'Account',
          ]) {
            expect(find.text(title), findsOneWidget, reason: 'missing $title');
          }

          await tester.binding.setSurfaceSize(null);
        });

        testWidgets('rate field uses theme colors in $sizeLabel $themeLabel', (
          tester,
        ) async {
          await _pumpSettings(tester, size: size, brightness: brightness);

          final theme = testTheme(brightness: brightness);
          final decoration = tester.widget<TextField>(_rateField()).decoration!;

          // Fill comes from the scheme, never from a fixed white.
          expect(decoration.fillColor, theme.colorScheme.surface);

          // Border comes from the scheme.
          expect(
            decoration.enabledBorder?.borderSide.color,
            theme.colorScheme.outline,
          );
          expect(
            decoration.focusedBorder?.borderSide.color,
            theme.colorScheme.primary,
          );

          // Label and prefix are neutral, not the brand blue.
          expect(
            decoration.labelStyle?.color,
            theme.colorScheme.onSurfaceVariant,
          );
          expect(
            decoration.floatingLabelStyle?.color,
            theme.colorScheme.onSurfaceVariant,
          );
          expect(
            (decoration.prefixIcon! as Icon).color,
            theme.colorScheme.onSurfaceVariant,
          );
          expect(
            decoration.suffixStyle?.color,
            theme.colorScheme.onSurfaceVariant,
          );

          await tester.binding.setSurfaceSize(null);
        });

        testWidgets(
          'rate field background is not white in $sizeLabel $themeLabel',
          (tester) async {
            await _pumpSettings(tester, size: size, brightness: brightness);

            final decoration = tester
                .widget<TextField>(_rateField())
                .decoration!;

            if (brightness == Brightness.dark) {
              expect(decoration.fillColor, isNot(Colors.white));
              expect(decoration.fillColor, isNot(const Color(0xFFFFFFFF)));
            }

            await tester.binding.setSurfaceSize(null);
          },
        );

        testWidgets(
          'content does not stretch edge to edge in $sizeLabel $themeLabel',
          (tester) async {
            await _pumpSettings(tester, size: size, brightness: brightness);

            final cardWidth = tester.getSize(find.byType(AppCard).first).width;

            // design.md: settings content is capped at 720.
            expect(cardWidth, lessThanOrEqualTo(720));
            if (size.width >= 900) {
              expect(cardWidth, lessThan(size.width - 48));
            }

            await tester.binding.setSurfaceSize(null);
          },
        );
      }
    }
  });
}

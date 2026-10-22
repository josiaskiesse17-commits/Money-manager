import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app/theme.dart';

void main() {
  group('AppTheme input decoration', () {
    test('light theme takes every field color from the light scheme', () {
      final theme = AppTheme.light();
      final decoration = theme.inputDecorationTheme;
      final colors = theme.colorScheme;

      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, colors.surface);
      expect(decoration.border?.borderSide.color, colors.outline);
      expect(decoration.enabledBorder?.borderSide.color, colors.outline);
      expect(decoration.focusedBorder?.borderSide.color, colors.primary);
      expect(decoration.errorBorder?.borderSide.color, colors.error);
      expect(decoration.focusedErrorBorder?.borderSide.color, colors.error);
      expect(decoration.labelStyle?.color, colors.onSurfaceVariant);
      expect(decoration.hintStyle?.color, colors.onSurfaceVariant);
      expect(decoration.helperStyle?.color, colors.onSurfaceVariant);
      expect(decoration.errorStyle?.color, colors.error);
    });

    test('dark theme takes every field color from the dark scheme', () {
      final theme = AppTheme.dark();
      final decoration = theme.inputDecorationTheme;
      final colors = theme.colorScheme;

      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, colors.surface);
      expect(decoration.border?.borderSide.color, colors.outline);
      expect(decoration.enabledBorder?.borderSide.color, colors.outline);
      expect(decoration.focusedBorder?.borderSide.color, colors.primary);
      expect(decoration.errorBorder?.borderSide.color, colors.error);
      expect(decoration.focusedErrorBorder?.borderSide.color, colors.error);
      expect(decoration.labelStyle?.color, colors.onSurfaceVariant);
      expect(decoration.hintStyle?.color, colors.onSurfaceVariant);
      expect(decoration.helperStyle?.color, colors.onSurfaceVariant);
      expect(decoration.errorStyle?.color, colors.error);
    });

    test('the dark theme never fills a field with white', () {
      final decoration = AppTheme.dark().inputDecorationTheme;

      expect(decoration.fillColor, isNot(Colors.white));
      expect(decoration.fillColor, isNot(const Color(0xFFFFFFFF)));
    });
  });

  group('AppTheme rendered fields', () {
    testWidgets('a bare text field is not white in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: TextField()),
        ),
      );

      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.fillColor, isNot(Colors.white));
      expect(
        decorator.decoration.fillColor,
        AppTheme.dark().colorScheme.surface,
      );
    });

    testWidgets('a bare text field is not white in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TextField()),
        ),
      );

      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(
        decorator.decoration.fillColor,
        AppTheme.light().colorScheme.surface,
      );
    });
  });
}

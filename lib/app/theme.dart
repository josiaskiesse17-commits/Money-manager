import 'package:flutter/material.dart';

/// Money Manager design system theme.
///
/// Defines light and dark [ColorScheme]s plus a [MoneyColors] ThemeExtension
/// for semantic colors (income, expense, warning, accent). Component themes
/// (input, button, card, chip, snackbar) are set here so screens never use
/// hard-coded colors or sizes.

/// Light theme colors.
const _lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0F5FA8),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD7E7F5),
  onPrimaryContainer: Color(0xFF0A3D6A),
  secondary: Color(0xFF5B6575),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF111827),
  surfaceVariant: Color(0xFFE9EDF3),
  onSurfaceVariant: Color(0xFF5B6575),
  background: Color(0xFFF4F6F9),
  onBackground: Color(0xFF111827),
  error: Color(0xFFC73E2E),
  onError: Color(0xFFFFFFFF),
  outline: Color(0xFFD5DBE4),
  outlineVariant: Color(0xFFE9EDF3),
  inverseSurface: Color(0xFF111827),
  inversePrimary: Color(0xFF5AA2E6),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF0F5FA8),
);

/// Dark theme colors.
const _darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF5AA2E6),
  onPrimary: Color(0xFF08233F),
  primaryContainer: Color(0xFF1F3A57),
  onPrimaryContainer: Color(0xFFD7E7F5),
  secondary: Color(0xFF9AA6B6),
  onSecondary: Color(0xFF0E1319),
  surface: Color(0xFF161D26),
  onSurface: Color(0xFFEEF2F7),
  surfaceVariant: Color(0xFF1F2833),
  onSurfaceVariant: Color(0xFF9AA6B6),
  background: Color(0xFF0E1319),
  onBackground: Color(0xFFEEF2F7),
  error: Color(0xFFF0786A),
  onError: Color(0xFF08233F),
  outline: Color(0xFF2B3644),
  outlineVariant: Color(0xFF1F2833),
  inverseSurface: Color(0xFFEEF2F7),
  inversePrimary: Color(0xFF0F5FA8),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF5AA2E6),
);

/// Semantic color extension used across the app.
class MoneyColors extends ThemeExtension<MoneyColors> {
  final Color income;
  final Color expense;
  final Color warning;
  final Color accent;

  const MoneyColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.accent,
  });

  @override
  MoneyColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? accent,
  }) {
    return MoneyColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
    );
  }

  @override
  MoneyColors lerp(ThemeExtension<MoneyColors>? other, double t) {
    if (other is! MoneyColors) return this;
    return MoneyColors(
      income: Color.lerp(this.income, other.income, t) ?? this.income,
      expense: Color.lerp(this.expense, other.expense, t) ?? this.expense,
      warning: Color.lerp(this.warning, other.warning, t) ?? this.warning,
      accent: Color.lerp(this.accent, other.accent, t) ?? this.accent,
    );
  }
}

const _lightMoneyColors = MoneyColors(
  income: Color(0xFF1B8A4B),
  expense: Color(0xFFC73E2E),
  warning: Color(0xFFC98A00),
  accent: Color(0xFFE8B019),
);

const _darkMoneyColors = MoneyColors(
  income: Color(0xFF4CC27F),
  expense: Color(0xFFF0786A),
  warning: Color(0xFFE0A82E),
  accent: Color(0xFFF0BE3A),
);

/// AppTheme builds full [ThemeData] for light and dark.
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
      extensions: [_lightMoneyColors],
      textTheme: _textTheme,
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
        margin: const EdgeInsets.all(0),
      ),
      chipTheme: _chipTheme,
      snackBarTheme: _snackBarTheme,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      extensions: [_darkMoneyColors],
      textTheme: _textTheme,
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
        margin: const EdgeInsets.all(0),
      ),
      chipTheme: _chipTheme,
      snackBarTheme: _snackBarTheme,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }
}

/// Shared text scale (Material 3). Amounts use tabular figures in [AmountText].
final _textTheme = TextTheme(
  displayLarge: const TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  ),
  displayMedium: const TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  ),
  headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
  headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
  titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
  labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
);

final _inputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFF0F5FA8), width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFC73E2E)),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFC73E2E), width: 2),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  helperStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
  errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
  hintStyle: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Color(0xFF5B6575),
  ),
);

final _elevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    shadowColor: Colors.transparent,
  ),
);

final _outlinedButtonTheme = OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
    padding: const EdgeInsets.symmetric(vertical: 16),
    side: const BorderSide(color: Color(0xFFD5DBE4)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

final _textButtonTheme = TextButtonThemeData(
  style: TextButton.styleFrom(
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);

final _chipTheme = ChipThemeData(
  backgroundColor: const Color(0xFFF4F6F9),
  disabledColor: const Color(0xFFE9EDF3),
  selectedColor: const Color(0xFF0F5FA8),
  secondarySelectedColor: const Color(0xFFFFFFFF),
  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  secondaryLabelStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFFFFFFFF),
  ),
  shape: const StadiumBorder(),
  brightness: Brightness.light,
);

final _snackBarTheme = SnackBarThemeData(
  backgroundColor: const Color(0xFF111827),
  contentTextStyle: const TextStyle(fontSize: 14, color: Color(0xFFFFFFFF)),
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  elevation: 0,
);

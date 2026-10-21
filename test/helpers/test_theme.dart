import 'package:flutter/material.dart';
import 'package:money_manager/app/theme.dart';

import 'test_fonts.dart';

/// Builds the app theme for widget tests with the real Roboto font.
///
/// `flutter test` runs with `--use-test-fonts`, which renders every glyph as
/// a 1em-wide box (the "Ahem" font). Real text is much narrower, so text laid
/// out with the test font reports false overflows. Applying the Roboto family
/// (loaded by [loadTestFonts]) to the theme text styles gives the tests the
/// same metrics as the device.
ThemeData testTheme({Brightness brightness = Brightness.light}) {
  final base = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

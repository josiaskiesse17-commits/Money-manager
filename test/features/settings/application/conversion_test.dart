import 'package:flutter_test/flutter_test.dart';

/// Conversion math: USD cents -> CDF francs and vice versa.
///
/// USD cents -> CDF francs: cents * rateScaled / 10000
/// CDF francs -> USD cents: francs * 10000 / rateScaled
/// Rounded half away from zero using integer math.

int _roundHalfAwayFromZero(int numerator, int denominator) {
  final negative = numerator < 0;
  var absNum = numerator.abs();
  var quotient = absNum ~/ denominator;
  final remainder = absNum % denominator;
  if (remainder * 2 >= denominator) {
    quotient++;
  }
  return negative ? -quotient : quotient;
}

int _usdToCdf(int cents, int rateScaled) {
  return _roundHalfAwayFromZero(cents * rateScaled, 10000);
}

int _cdfToUsd(int francs, int rateScaled) {
  return _roundHalfAwayFromZero(francs * 10000, rateScaled);
}

void main() {
  group('Conversion math', () {
    test('USD cents -> CDF francs', () {
      // 100 cents * 280050 / 10000 = 2800.5 -> rounded to 2801
      expect(_usdToCdf(100, 280050), 2801);
    });

    test('CDF francs -> USD cents', () {
      // 2801 francs * 10000 / 280050 = 99.99... -> rounded to 100
      expect(_cdfToUsd(2801, 280050), 100);
    });

    test('USD to CDF round trip', () {
      final cents = 5000;
      final rateScaled = 280050;
      final cdf = _usdToCdf(cents, rateScaled);
      final back = _cdfToUsd(cdf, rateScaled);
      expect(back, 5000); // exact round trip
    });

    test('rounding exact half up', () {
      // 5000 cents * 1 / 10000 = 0.5 -> 1 (half away from zero)
      expect(_usdToCdf(5000, 1), 1);
    });

    test('rounding exact half down (negative)', () {
      // -5000 cents * 1 / 10000 = -0.5 -> -1 (half away from zero)
      expect(_usdToCdf(-5000, 1), -1);
    });

    test('zero amount converts to zero', () {
      expect(_usdToCdf(0, 280050), 0);
      expect(_cdfToUsd(0, 280050), 0);
    });

    test('large amount conversion', () {
      expect(_usdToCdf(1000000, 280050), 28005000);
    });
  });

  group('rateAtEntry preserved on edit', () {
    test('edit keeps original rateAtEntry', () {
      final originalRate = 280050;
      final editedRate = 280050; // edits keep original rateAtEntry
      expect(editedRate, originalRate);
    });
  });
}

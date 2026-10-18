import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/money/currency.dart';
import 'package:money_manager/core/money/money.dart';

void main() {
  group('Money.parse', () {
    test('USD parses dollars and cents', () {
      expect(
        Money.parse('1234.50', Currency.usd),
        const Money(amount: 123450, currency: Currency.usd),
      );
    });

    test('USD parses whole dollars', () {
      expect(
        Money.parse('1234', Currency.usd),
        const Money(amount: 123400, currency: Currency.usd),
      );
    });

    test('USD parses with comma thousands separator', () {
      expect(
        Money.parse('1,234.50', Currency.usd),
        const Money(amount: 123450, currency: Currency.usd),
      );
    });

    test('USD parses European format', () {
      expect(
        Money.parse('1.234,50', Currency.usd),
        const Money(amount: 123450, currency: Currency.usd),
      );
    });

    test('USD parses one decimal', () {
      expect(
        Money.parse('12.5', Currency.usd),
        const Money(amount: 1250, currency: Currency.usd),
      );
    });

    test('USD parses negative', () {
      expect(
        Money.parse('-1234.50', Currency.usd),
        const Money(amount: -123450, currency: Currency.usd),
      );
    });

    test('CDF parses whole francs', () {
      expect(
        Money.parse('35000', Currency.cdf),
        const Money(amount: 35000, currency: Currency.cdf),
      );
    });

    test('CDF parses with comma thousands separator', () {
      expect(
        Money.parse('35,000', Currency.cdf),
        const Money(amount: 35000, currency: Currency.cdf),
      );
    });

    test('CDF rejects decimals', () {
      expect(() => Money.parse('35.50', Currency.cdf), throwsFormatException);
      expect(() => Money.parse('35,50', Currency.cdf), throwsFormatException);
    });

    test('rejects invalid text', () {
      expect(() => Money.parse('abc', Currency.usd), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('USD formats with dollars and cents', () {
      expect(
        const Money(amount: 123450, currency: Currency.usd).format(),
        '\$1,234.50',
      );
    });

    test('USD formats whole dollars', () {
      expect(
        const Money(amount: 123400, currency: Currency.usd).format(),
        '\$1,234.00',
      );
    });

    test('USD formats negative', () {
      expect(
        const Money(amount: -123450, currency: Currency.usd).format(),
        '-\$1,234.50',
      );
    });

    test('CDF formats with FC suffix', () {
      expect(
        const Money(amount: 35000, currency: Currency.cdf).format(),
        '35,000 FC',
      );
    });

    test('CDF formats negative', () {
      expect(
        const Money(amount: -35000, currency: Currency.cdf).format(),
        '-35,000 FC',
      );
    });

    test('USD formats small amount', () {
      expect(const Money(amount: 5, currency: Currency.usd).format(), '\$0.05');
    });
  });

  group('Money.convertTo', () {
    test('USD to CDF', () {
      final result = const Money(
        amount: 100,
        currency: Currency.usd,
      ).convertTo(Currency.cdf, 280050);
      // 100 * 280050 / 10000 = 2800.5 -> rounded half away from zero = 2801
      expect(result, const Money(amount: 2801, currency: Currency.cdf));
    });

    test('CDF to USD', () {
      final result = const Money(
        amount: 2801,
        currency: Currency.cdf,
      ).convertTo(Currency.usd, 280050);
      // 2801 * 10000 / 280050 = 99.99... -> 100
      expect(result, const Money(amount: 100, currency: Currency.usd));
    });

    test('same currency returns same amount', () {
      final m = const Money(amount: 500, currency: Currency.usd);
      expect(m.convertTo(Currency.usd, 280050), m);
    });

    test('rounding half away from zero positive', () {
      // 1 cent * 280050 / 10000 = 28.005 -> 28
      final result = const Money(
        amount: 1,
        currency: Currency.usd,
      ).convertTo(Currency.cdf, 280050);
      expect(result, const Money(amount: 28, currency: Currency.cdf));
    });

    test('rounding exact half up', () {
      // 5000 cents * 1 / 10000 = 0.5 -> 1 (half away from zero)
      final result = const Money(
        amount: 5000,
        currency: Currency.usd,
      ).convertTo(Currency.cdf, 1);
      expect(result, const Money(amount: 1, currency: Currency.cdf));
    });

    test('rounding exact half down (negative)', () {
      // -5000 cents * 1 / 10000 = -0.5 -> -1 (half away from zero)
      final result = const Money(
        amount: -5000,
        currency: Currency.usd,
      ).convertTo(Currency.cdf, 1);
      expect(result, const Money(amount: -1, currency: Currency.cdf));
    });
  });

  group('Money add/subtract', () {
    test('add same currency', () {
      final result =
          const Money(amount: 100, currency: Currency.usd) +
          const Money(amount: 50, currency: Currency.usd);
      expect(result, const Money(amount: 150, currency: Currency.usd));
    });

    test('subtract same currency', () {
      final result =
          const Money(amount: 100, currency: Currency.usd) -
          const Money(amount: 50, currency: Currency.usd);
      expect(result, const Money(amount: 50, currency: Currency.usd));
    });

    test('add different currencies throws', () {
      expect(
        () =>
            const Money(amount: 100, currency: Currency.usd) +
            const Money(amount: 50, currency: Currency.cdf),
        throwsArgumentError,
      );
    });

    test('subtract different currencies throws', () {
      expect(
        () =>
            const Money(amount: 100, currency: Currency.usd) -
            const Money(amount: 50, currency: Currency.cdf),
        throwsArgumentError,
      );
    });
  });

  group('Equality and hashCode', () {
    test('equal amounts and currencies are equal', () {
      expect(
        const Money(amount: 100, currency: Currency.usd),
        const Money(amount: 100, currency: Currency.usd),
      );
    });

    test('different amounts are not equal', () {
      expect(
        const Money(amount: 100, currency: Currency.usd),
        isNot(equals(const Money(amount: 200, currency: Currency.usd))),
      );
    });

    test('different currencies are not equal', () {
      expect(
        const Money(amount: 100, currency: Currency.usd),
        isNot(equals(const Money(amount: 100, currency: Currency.cdf))),
      );
    });
  });

  group('ExchangeRate.parse', () {
    test('parses standard format', () {
      expect(
        ExchangeRate.parse('2800.50'),
        const ExchangeRate(rateScaled: 280050),
      );
    });

    test('parses with comma thousands', () {
      expect(
        ExchangeRate.parse('2,800.50'),
        const ExchangeRate(rateScaled: 280050),
      );
    });

    test('parses European format', () {
      expect(
        ExchangeRate.parse('2800,50'),
        const ExchangeRate(rateScaled: 280050),
      );
    });

    test('parses whole number', () {
      expect(
        ExchangeRate.parse('2800'),
        const ExchangeRate(rateScaled: 280000),
      );
    });

    test('formats correctly', () {
      expect(const ExchangeRate(rateScaled: 280050).format(), '2,800.50');
    });

    test('rejects invalid text', () {
      expect(() => ExchangeRate.parse('abc'), throwsFormatException);
    });
  });
}

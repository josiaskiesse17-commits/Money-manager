import 'package:money_manager/core/money/currency.dart';

/// Parses a decimal string with optional thousands separators ("," or ".").
/// Returns the integer value scaled by [scale] (e.g. scale=2 -> cents).
/// Throws [FormatException] if the text is invalid or has too many decimals.
int _parseScaled(String text, int scale) {
  text = text.replaceAll(' ', '');

  final hasComma = text.contains(',');
  final hasDot = text.contains('.');

  String digits;
  int decimalPlaces;

  if (hasComma && hasDot) {
    final lastComma = text.lastIndexOf(',');
    final lastDot = text.lastIndexOf('.');
    if (lastComma > lastDot) {
      digits = text.substring(0, lastComma) + text.substring(lastComma + 1);
      digits = digits.replaceAll('.', '');
      decimalPlaces = text.length - lastComma - 1;
    } else {
      digits = text.substring(0, lastDot) + text.substring(lastDot + 1);
      digits = digits.replaceAll(',', '');
      decimalPlaces = text.length - lastDot - 1;
    }
  } else if (hasComma) {
    final lastComma = text.lastIndexOf(',');
    final after = text.substring(lastComma + 1);
    if (after.isNotEmpty && after.length <= 2 && int.tryParse(after) != null) {
      digits = text.replaceAll(',', '');
      decimalPlaces = after.length;
    } else {
      digits = text.replaceAll(',', '');
      decimalPlaces = 0;
    }
  } else if (hasDot) {
    final lastDot = text.lastIndexOf('.');
    final after = text.substring(lastDot + 1);
    if (after.isNotEmpty && after.length <= 2 && int.tryParse(after) != null) {
      digits = text.replaceAll('.', '');
      decimalPlaces = after.length;
    } else {
      digits = text.replaceAll('.', '');
      decimalPlaces = 0;
    }
  } else {
    digits = text;
    decimalPlaces = 0;
  }

  if (digits.isEmpty || int.tryParse(digits) == null) {
    throw FormatException('Invalid number: $text');
  }

  var value = int.parse(digits);

  if (decimalPlaces > scale) {
    throw FormatException('Max $scale decimal places allowed: $text');
  }

  for (var i = 0; i < scale - decimalPlaces; i++) {
    value *= 10;
  }

  return value;
}

/// Formats an integer with "," thousands separators.
String _formatInt(int value) {
  final s = value.abs().toString();
  if (s.length <= 3) return s;
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      sb.write(',');
    }
    sb.write(s[i]);
  }
  return sb.toString();
}

/// Rounds [numerator] / [denominator] half away from zero using integer math.
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

/// Money in minor units (integer). Never use [double] for money.
/// - USD: minor unit = cent (2 decimals)
/// - CDF: minor unit = franc (0 decimals)
class Money {
  final int amount;
  final Currency currency;

  const Money({required this.amount, required this.currency});

  /// Parses a monetary string into [Money].
  /// CDF amounts must be whole francs (no decimals).
  /// USD amounts accept up to 2 decimals with "," or ".".
  factory Money.parse(String text, Currency currency) {
    if (currency == Currency.cdf) {
      // CDF: no decimals allowed. Parse as integer, reject any decimal separator.
      final cleaned = text
          .replaceAll(' ', '')
          .replaceAll(',', '')
          .replaceAll('.', '');
      if (cleaned.isEmpty || int.tryParse(cleaned) == null) {
        throw FormatException('Invalid CDF amount: $text');
      }
      // Reject if original had a decimal separator followed by digits
      final hasComma = text.contains(',');
      final hasDot = text.contains('.');
      if (hasComma || hasDot) {
        late int decimalPlaces;
        if (hasComma && hasDot) {
          final lastComma = text.lastIndexOf(',');
          final lastDot = text.lastIndexOf('.');
          final lastSep = lastComma > lastDot ? lastComma : lastDot;
          decimalPlaces = text.length - lastSep - 1;
        } else if (hasComma) {
          decimalPlaces = text.length - text.lastIndexOf(',') - 1;
        } else {
          decimalPlaces = text.length - text.lastIndexOf('.') - 1;
        }
        // Only reject if separator is followed by 1-2 digits (decimal usage).
        // If followed by 3 digits, it's a thousands separator (OK for CDF).
        if (decimalPlaces >= 1 && decimalPlaces <= 2) {
          throw FormatException('CDF amounts must be whole francs: $text');
        }
      }
      return Money(amount: int.parse(cleaned), currency: currency);
    }

    // USD: up to 2 decimals
    final value = _parseScaled(text, 2);
    return Money(amount: value, currency: currency);
  }

  /// Formats for display: `$1,234.50` for USD, `35,000 FC` for CDF.
  String format() {
    final prefix = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    switch (currency) {
      case Currency.usd:
        final dollars = absAmount ~/ 100;
        final cents = absAmount % 100;
        return '$prefix\$${_formatInt(dollars)}.${cents.toString().padLeft(2, '0')}';
      case Currency.cdf:
        return '$prefix${_formatInt(absAmount)} FC';
    }
  }

  /// Converts to [target] currency using [rateScaled] (CDF per 1 USD, x100).
  /// Uses integer math, rounded half away from zero:
  ///   USD cents -> CDF francs:  cents * rateScaled / 10000
  ///   CDF francs -> USD cents:  francs * 10000 / rateScaled
  Money convertTo(Currency target, int rateScaled) {
    if (currency == target) {
      return Money(amount: amount, currency: target);
    }
    int result;
    if (currency == Currency.usd && target == Currency.cdf) {
      result = _roundHalfAwayFromZero(amount * rateScaled, 10000);
    } else {
      result = _roundHalfAwayFromZero(amount * 10000, rateScaled);
    }
    return Money(amount: result, currency: target);
  }

  Money copyWith({int? amount, Currency? currency}) {
    return Money(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
    );
  }

  Money operator +(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot add ${other.currency} to $currency');
    }
    return Money(amount: amount + other.amount, currency: currency);
  }

  Money operator -(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot subtract ${other.currency} from $currency');
    }
    return Money(amount: amount - other.amount, currency: currency);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          currency == other.currency;

  @override
  int get hashCode => amount.hashCode ^ currency.hashCode;

  @override
  String toString() => format();
}

/// Exchange rate: CDF per 1 USD, stored as integer scaled by 100.
/// e.g. 2800.50 -> 280050. Parsing accepts up to 2 decimals and "," or ".".
class ExchangeRate {
  final int rateScaled;

  const ExchangeRate({required this.rateScaled});

  /// Parses a rate string like "2800.50", "2,800.50", or "2800,50".
  factory ExchangeRate.parse(String text) {
    final value = _parseScaled(text, 2);
    return ExchangeRate(rateScaled: value);
  }

  /// Formats as "2,800.50".
  String format() {
    final whole = rateScaled ~/ 100;
    final frac = rateScaled % 100;
    return '${_formatInt(whole)}.${frac.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExchangeRate &&
          runtimeType == other.runtimeType &&
          rateScaled == other.rateScaled;

  @override
  int get hashCode => rateScaled.hashCode;
}

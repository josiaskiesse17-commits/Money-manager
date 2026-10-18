/// Currency supported by Money Manager.
enum Currency { cdf, usd }

extension CurrencyDisplay on Currency {
  String get symbol {
    switch (this) {
      case Currency.cdf:
        return 'FC';
      case Currency.usd:
        return '\$';
    }
  }

  String get name {
    switch (this) {
      case Currency.cdf:
        return 'Congolese Franc';
      case Currency.usd:
        return 'US Dollar';
    }
  }

  /// Number of decimal places for this currency's minor units.
  int get decimalPlaces {
    switch (this) {
      case Currency.cdf:
        return 0;
      case Currency.usd:
        return 2;
    }
  }
}

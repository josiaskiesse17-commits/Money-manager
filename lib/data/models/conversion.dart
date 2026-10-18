import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversion between wallets (doc: users/{uid}/conversions/{id}).
/// Not income/expense; excluded from budgets, charts, totals.
class Conversion {
  final String id;
  final String fromCurrency; // CDF | USD
  final String toCurrency; // CDF | USD
  final int fromAmount; // minor units
  final int toAmount; // minor units
  final int rate; // rate x100 used for this conversion
  final DateTime date;

  const Conversion({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.toAmount,
    required this.rate,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'fromCurrency': fromCurrency,
      'toCurrency': toCurrency,
      'fromAmount': fromAmount,
      'toAmount': toAmount,
      'rate': rate,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Conversion.fromMap(String id, Map<String, dynamic> map) {
    return Conversion(
      id: id,
      fromCurrency: map['fromCurrency'] as String,
      toCurrency: map['toCurrency'] as String,
      fromAmount: map['fromAmount'] as int,
      toAmount: map['toAmount'] as int,
      rate: map['rate'] as int,
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  factory Conversion.fromDocument(DocumentSnapshot doc) {
    return Conversion.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Conversion copyWith({
    String? id,
    String? fromCurrency,
    String? toCurrency,
    int? fromAmount,
    int? toAmount,
    int? rate,
    DateTime? date,
  }) {
    return Conversion(
      id: id ?? this.id,
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      fromAmount: fromAmount ?? this.fromAmount,
      toAmount: toAmount ?? this.toAmount,
      rate: rate ?? this.rate,
      date: date ?? this.date,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fromCurrency == other.fromCurrency &&
          toCurrency == other.toCurrency &&
          fromAmount == other.fromAmount &&
          toAmount == other.toAmount &&
          rate == other.rate &&
          date == other.date;

  @override
  int get hashCode =>
      id.hashCode ^
      fromCurrency.hashCode ^
      toCurrency.hashCode ^
      fromAmount.hashCode ^
      toAmount.hashCode ^
      rate.hashCode ^
      date.hashCode;
}

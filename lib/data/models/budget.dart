import 'package:cloud_firestore/cloud_firestore.dart';

/// Budget per category (doc: users/{uid}/budgets/{categoryId}).
/// One budget per expense category; doc id = categoryId.
class Budget {
  final String categoryId;
  final String currency; // CDF | USD
  final int monthlyLimit; // minor units

  const Budget({
    required this.categoryId,
    required this.currency,
    required this.monthlyLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'currency': currency,
      'monthlyLimit': monthlyLimit,
    };
  }

  factory Budget.fromMap(String id, Map<String, dynamic> map) {
    return Budget(
      categoryId: id,
      currency: map['currency'] as String,
      monthlyLimit: map['monthlyLimit'] as int,
    );
  }

  factory Budget.fromDocument(DocumentSnapshot doc) {
    return Budget.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Budget copyWith({String? categoryId, String? currency, int? monthlyLimit}) {
    return Budget(
      categoryId: categoryId ?? this.categoryId,
      currency: currency ?? this.currency,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Budget &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          currency == other.currency &&
          monthlyLimit == other.monthlyLimit;

  @override
  int get hashCode =>
      categoryId.hashCode ^ currency.hashCode ^ monthlyLimit.hashCode;
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Debt payment (doc: users/{uid}/debtPayments/{id}).
/// amount is in minor units (> 0), currency matches the debt's currency.
class DebtPayment {
  final String id;
  final String debtId;
  final int amount; // minor units, > 0
  final String currency; // CDF | USD
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.currency,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'debtId': debtId,
      'amount': amount,
      'currency': currency,
      'date': Timestamp.fromDate(date),
      'note': note ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DebtPayment.fromMap(String id, Map<String, dynamic> map) {
    return DebtPayment(
      id: id,
      debtId: map['debtId'] as String,
      amount: map['amount'] as int,
      currency: map['currency'] as String,
      date: (map['date'] as Timestamp).toDate(),
      note: _noteFromMap(map['note']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  factory DebtPayment.fromDocument(DocumentSnapshot doc) {
    return DebtPayment.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  DebtPayment copyWith({
    String? id,
    String? debtId,
    int? amount,
    String? currency,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return DebtPayment(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String? _noteFromMap(dynamic raw) {
    final s = raw as String?;
    return (s != null && s.isNotEmpty) ? s : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtPayment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          debtId == other.debtId &&
          amount == other.amount &&
          currency == other.currency &&
          date == other.date &&
          note == other.note &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      debtId.hashCode ^
      amount.hashCode ^
      currency.hashCode ^
      date.hashCode ^
      note.hashCode ^
      createdAt.hashCode;
}

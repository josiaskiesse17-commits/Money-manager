import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction (doc: users/{uid}/transactions/{id}).
/// amount is in minor units (> 0). rateAtEntry is rate x100 when entered.
class Transaction {
  final String id;
  final int amount; // minor units, > 0
  final String currency; // CDF | USD
  final String type; // income | expense
  final String categoryId;
  final DateTime date;
  final String? note; // max 200 chars
  final int rateAtEntry; // rate x100 when entered
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Transaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.categoryId,
    required this.date,
    this.note,
    required this.rateAtEntry,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'currency': currency,
      'type': type,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date),
      'note': note ?? '',
      'rateAtEntry': rateAtEntry,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    return Transaction(
      id: id,
      amount: map['amount'] as int,
      currency: map['currency'] as String,
      type: map['type'] as String,
      categoryId: map['categoryId'] as String,
      date: (map['date'] as Timestamp).toDate(),
      note: _noteFromMap(map['note']),
      rateAtEntry: map['rateAtEntry'] as int,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts a stored note to a display value: an empty string stored in
  /// Firestore is treated as "no note" (null) in the UI.
  static String? _noteFromMap(dynamic raw) {
    final s = raw as String?;
    return (s != null && s.isNotEmpty) ? s : null;
  }

  factory Transaction.fromDocument(DocumentSnapshot doc) {
    return Transaction.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Transaction copyWith({
    String? id,
    int? amount,
    String? currency,
    String? type,
    String? categoryId,
    DateTime? date,
    String? note,
    int? rateAtEntry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      rateAtEntry: rateAtEntry ?? this.rateAtEntry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          currency == other.currency &&
          type == other.type &&
          categoryId == other.categoryId &&
          date == other.date &&
          note == other.note &&
          rateAtEntry == other.rateAtEntry &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      currency.hashCode ^
      type.hashCode ^
      categoryId.hashCode ^
      date.hashCode ^
      note.hashCode ^
      rateAtEntry.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}

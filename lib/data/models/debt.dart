import 'package:cloud_firestore/cloud_firestore.dart';

/// Debt (doc: users/{uid}/debts/{id}).
/// direction: 'owe' = I owe someone, 'owed' = someone owes me.
/// Money is in the debt's currency only (minor units).
class Debt {
  final String id;
  final String name;
  final String direction; // 'owe' | 'owed'
  final String currency; // CDF | USD
  final int principal; // minor units, > 0
  final int remaining; // minor units, maintained with increments
  final DateTime? dueDate;
  final String? note;
  final bool archived;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.name,
    required this.direction,
    required this.currency,
    required this.principal,
    required this.remaining,
    this.dueDate,
    this.note,
    required this.archived,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'direction': direction,
      'currency': currency,
      'principal': principal,
      'remaining': remaining,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'note': note ?? '',
      'archived': archived,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Debt.fromMap(String id, Map<String, dynamic> map) {
    return Debt(
      id: id,
      name: map['name'] as String,
      direction: map['direction'] as String,
      currency: map['currency'] as String,
      principal: map['principal'] as int,
      remaining: map['remaining'] as int,
      dueDate: map['dueDate'] != null
          ? (map['dueDate'] as Timestamp).toDate()
          : null,
      note: _noteFromMap(map['note']),
      archived: map['archived'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  factory Debt.fromDocument(DocumentSnapshot doc) {
    return Debt.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Debt copyWith({
    String? id,
    String? name,
    String? direction,
    String? currency,
    int? principal,
    int? remaining,
    DateTime? dueDate,
    String? note,
    bool? archived,
    DateTime? createdAt,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      currency: currency ?? this.currency,
      principal: principal ?? this.principal,
      remaining: remaining ?? this.remaining,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      archived: archived ?? this.archived,
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
      other is Debt &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          direction == other.direction &&
          currency == other.currency &&
          principal == other.principal &&
          remaining == other.remaining &&
          dueDate == other.dueDate &&
          note == other.note &&
          archived == other.archived &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      direction.hashCode ^
      currency.hashCode ^
      principal.hashCode ^
      remaining.hashCode ^
      dueDate.hashCode ^
      note.hashCode ^
      archived.hashCode ^
      createdAt.hashCode;
}

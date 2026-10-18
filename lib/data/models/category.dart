import 'package:cloud_firestore/cloud_firestore.dart';

/// Category (doc: users/{uid}/categories/{id}).
class Category {
  final String id;
  final String name;
  final String icon; // icon key
  final int color; // ARGB int
  final String type; // income | expense
  final bool archived;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.archived,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
      'archived': archived,
    };
  }

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      type: map['type'] as String,
      archived: map['archived'] as bool,
    );
  }

  factory Category.fromDocument(DocumentSnapshot doc) {
    return Category.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    int? color,
    String? type,
    bool? archived,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      archived: archived ?? this.archived,
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          color == other.color &&
          type == other.type &&
          archived == other.archived;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      icon.hashCode ^
      color.hashCode ^
      type.hashCode ^
      archived.hashCode;
}

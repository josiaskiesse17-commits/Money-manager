import 'package:cloud_firestore/cloud_firestore.dart';

/// User settings (doc: users/{uid}/settings/main).
class Setting {
  final String docId;
  final int usdToCdfRate; // CDF per 1 USD, x100
  final String theme; // light | dark | system
  final String displayMode; // cdf | usd | combined
  final bool onboarded;

  const Setting({
    required this.docId,
    required this.usdToCdfRate,
    required this.theme,
    required this.displayMode,
    required this.onboarded,
  });

  Map<String, dynamic> toMap() {
    return {
      'usdToCdfRate': usdToCdfRate,
      'theme': theme,
      'displayMode': displayMode,
      'onboarded': onboarded,
    };
  }

  factory Setting.fromMap(String docId, Map<String, dynamic> map) {
    return Setting(
      docId: docId,
      usdToCdfRate: map['usdToCdfRate'] as int,
      theme: map['theme'] as String,
      displayMode: map['displayMode'] as String,
      onboarded: map['onboarded'] as bool,
    );
  }

  factory Setting.fromDocument(DocumentSnapshot doc) {
    return Setting.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Setting copyWith({
    String? docId,
    int? usdToCdfRate,
    String? theme,
    String? displayMode,
    bool? onboarded,
  }) {
    return Setting(
      docId: docId ?? this.docId,
      usdToCdfRate: usdToCdfRate ?? this.usdToCdfRate,
      theme: theme ?? this.theme,
      displayMode: displayMode ?? this.displayMode,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Setting &&
          runtimeType == other.runtimeType &&
          docId == other.docId &&
          usdToCdfRate == other.usdToCdfRate &&
          theme == other.theme &&
          displayMode == other.displayMode &&
          onboarded == other.onboarded;

  @override
  int get hashCode =>
      docId.hashCode ^
      usdToCdfRate.hashCode ^
      theme.hashCode ^
      displayMode.hashCode ^
      onboarded.hashCode;
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Wallet balance (doc: users/{uid}/wallets/{currency}).
class Wallet {
  final String currency; // CDF | USD
  final int openingBalance; // minor units
  final int balance; // minor units, maintained by increments

  const Wallet({
    required this.currency,
    required this.openingBalance,
    required this.balance,
  });

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'openingBalance': openingBalance,
      'balance': balance,
    };
  }

  factory Wallet.fromMap(String currency, Map<String, dynamic> map) {
    return Wallet(
      currency: currency,
      openingBalance: map['openingBalance'] as int,
      balance: map['balance'] as int,
    );
  }

  factory Wallet.fromDocument(DocumentSnapshot doc) {
    return Wallet.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Wallet copyWith({String? currency, int? openingBalance, int? balance}) {
    return Wallet(
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      balance: balance ?? this.balance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallet &&
          runtimeType == other.runtimeType &&
          currency == other.currency &&
          openingBalance == other.openingBalance &&
          balance == other.balance;

  @override
  int get hashCode =>
      currency.hashCode ^ openingBalance.hashCode ^ balance.hashCode;
}

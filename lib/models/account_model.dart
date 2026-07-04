import 'package:flutter/material.dart';

/// A payment source the user tracks money in — cash on hand, a bank account,
/// a credit card, or a digital wallet. Every personal expense can be attributed
/// to one account so balances stay accurate and spending can be viewed per
/// source.
enum AccountType {
  cash('Cash', Icons.payments, Color(0xFF2E7D32)),
  bank('Bank', Icons.account_balance, Color(0xFF1565C0)),
  creditCard('Credit Card', Icons.credit_card, Color(0xFF6A1B9A)),
  wallet('Wallet', Icons.account_balance_wallet, Color(0xFFEF6C00));

  const AccountType(this.displayName, this.icon, this.color);

  final String displayName;
  final IconData icon;
  final Color color;
}

class AccountModel {
  final String id;
  final String userId;
  final String name;
  final AccountType type;

  /// Current balance in INR. Spending decreases it; income/refunds/incoming
  /// transfers increase it. Credit cards may go negative to represent debt.
  final double balance;
  final DateTime createdAt;

  AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    required this.createdAt,
  });

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: AccountType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AccountType.cash,
      ),
      balance: (map['balance'] ?? 0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type.name,
      'balance': balance,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  AccountModel copyWith({String? name, AccountType? type, double? balance}) {
    return AccountModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      createdAt: createdAt,
    );
  }

  IconData get icon => type.icon;
  Color get color => type.color;

  /// Balance formatted as e.g. `₹1,250` or `-₹300`. Whole rupees to match the
  /// rest of the app's money formatting.
  String get formattedBalance {
    final rounded = balance.round();
    final sign = rounded < 0 ? '-' : '';
    return '$sign₹${rounded.abs()}';
  }
}

/// A movement of money between two of the user's own accounts. Transfers change
/// both account balances but are NOT expenses — they never count toward
/// spending totals, budgets, or category reports.
class TransferModel {
  final String id;
  final String userId;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final String note;
  final DateTime createdAt;

  TransferModel({
    required this.id,
    required this.userId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  factory TransferModel.fromMap(Map<String, dynamic> map) {
    return TransferModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      fromAccountId: map['fromAccountId'] ?? '',
      toAccountId: map['toAccountId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

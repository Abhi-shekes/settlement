// enum ExpenseCategory {
//   food,
//   travel,
//   shopping,
//   entertainment,
//   utilities,
//   healthcare,
//   education,
//   other,
// }

enum ExpenseCategory {
  food('Food'),
  travel('Travel'),
  shopping('Shopping'),
  entertainment('Entertainment'),
  utilities('Utilities'),
  healthcare('Healthcare'),
  education('Education'),
  other('Other');

  const ExpenseCategory(this.categoryDisplayName);
  final String categoryDisplayName;
}

class ExpenseModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount; // Amount in INR
  final ExpenseCategory category;
  final DateTime createdAt;
  final String? groupId;
  final bool isSettled;

  /// The account this expense was paid from, if any. Nullable so existing
  /// expenses (created before accounts existed) and group expenses keep working.
  final String? accountId;

  /// When set, this record is a refund/reversal of the expense with this id.
  /// Refunds are stored with a NEGATIVE [amount] so they subtract from spending
  /// totals, category reports, and budgets, and credit their account — all via
  /// the same code paths as normal expenses, with no special-casing needed in
  /// the aggregation logic.
  final String? refundOfExpenseId;

  /// Set when this expense was auto-generated from a recurring rule, linking it
  /// back to that rule for traceability.
  final String? recurringId;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.groupId,
    this.isSettled = false,
    this.accountId,
    this.refundOfExpenseId,
    this.recurringId,
  });

  /// True when this record represents money coming back (a refund/reversal)
  /// rather than money spent.
  bool get isRefund => refundOfExpenseId != null;

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString() == map['category'],
        orElse: () => ExpenseCategory.other,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      groupId: map['groupId'],
      isSettled: map['isSettled'] ?? false,
      accountId: map['accountId'],
      refundOfExpenseId: map['refundOfExpenseId'],
      recurringId: map['recurringId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'groupId': groupId,
      'isSettled': isSettled,
      'accountId': accountId,
      'refundOfExpenseId': refundOfExpenseId,
      'recurringId': recurringId,
    };
  }

  String get categoryDisplayName {
    switch (category) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.travel:
        return 'Travel';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.healthcare:
        return 'Healthcare';
      case ExpenseCategory.education:
        return 'Education';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  /// Whole-rupee display. Refunds (negative amounts) are shown as a credit,
  /// e.g. `+₹200`.
  String get formattedAmount {
    if (amount < 0) return '+₹${(-amount).toInt()}';
    return '₹${amount.toInt()}';
  }
}

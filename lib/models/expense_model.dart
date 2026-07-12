import 'category_model.dart';

/// The fixed, built-in spending categories. Custom user-defined categories are
/// modelled by [Category]; these enum values seed the built-in [Category] set
/// (see `category_model.dart`). An expense stores its category as a string id
/// ([ExpenseModel.categoryId]); the resolved [Category] is exposed via
/// [ExpenseModel.category].
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

  /// Stored category identifier. For built-ins this is the [ExpenseCategory]
  /// enum string (e.g. `"ExpenseCategory.food"`); for custom categories it is
  /// the category's UUID. Resolve to a [Category] via [category].
  final String categoryId;
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
    required this.categoryId,
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

  /// The resolved category (built-in or custom). Resolved lazily through
  /// [CategoryRegistry] so a newly created custom category is reflected without
  /// reloading expenses.
  Category get category => CategoryRegistry.instance.byId(categoryId);

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      categoryId:
          (map['category'] ?? ExpenseCategory.other.toString()) as String,
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
      'category': categoryId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'groupId': groupId,
      'isSettled': isSettled,
      'accountId': accountId,
      'refundOfExpenseId': refundOfExpenseId,
      'recurringId': recurringId,
    };
  }

  /// Display name of the resolved category (built-in or custom).
  String get categoryDisplayName => category.categoryDisplayName;

  /// Whole-rupee display. Refunds (negative amounts) are shown as a credit,
  /// e.g. `+₹200`.
  String get formattedAmount {
    if (amount < 0) return '+₹${(-amount).toInt()}';
    return '₹${amount.toInt()}';
  }
}

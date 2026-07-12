import 'package:settlement/models/expense_model.dart';
import 'package:settlement/models/category_model.dart';

class BudgetModel {
  final String id;
  final String userId;

  /// Stored category identifier (built-in enum string or a custom category's
  /// UUID). Resolve to a [Category] via [category].
  final String categoryId;
  final double amount;
  final DateTime month; // First day of the month
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The resolved category (built-in or custom).
  Category get category => CategoryRegistry.instance.byId(categoryId);

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      categoryId:
          (map['category'] ?? ExpenseCategory.other.toString()) as String,
      amount: (map['amount'] ?? 0).toDouble(),
      month: DateTime.fromMillisecondsSinceEpoch(map['month'] ?? 0),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'category': categoryId,
      'amount': amount,
      'month': month.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    double? amount,
    DateTime? month,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedAmount => '₹${amount.toInt()}';

  String get monthYear => '${_getMonthName(month.month)} ${month.year}';

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

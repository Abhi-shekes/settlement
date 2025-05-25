enum ExpenseCategory {
  food,
  travel,
  shopping,
  entertainment,
  utilities,
  healthcare,
  education,
  other,
}

class ExpenseModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount; // Amount in INR
  final ExpenseCategory category;
  final DateTime createdAt;
  final List<String> tags;
  final String? groupId;
  final bool isSettled;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.tags = const [],
    this.groupId,
    this.isSettled = false,
  });

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
      tags: List<String>.from(map['tags'] ?? []),
      groupId: map['groupId'],
      isSettled: map['isSettled'] ?? false,
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
      'tags': tags,
      'groupId': groupId,
      'isSettled': isSettled,
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

  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';
}

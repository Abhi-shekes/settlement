enum SplitType { equal, unequal }

class SplitModel {
  final String id;
  final String title;
  final String description;
  final double totalAmount; // Total amount in INR
  final String paidBy; // User ID who paid
  final List<String> participants; // User IDs
  final SplitType splitType;
  final Map<String, double> splitAmounts; // User ID -> Amount owed
  final DateTime createdAt;
  final String? groupId;
  final String notes;
  final bool isFullySettled;
  final List<SettlementModel> settlements;

  SplitModel({
    required this.id,
    required this.title,
    required this.description,
    required this.totalAmount,
    required this.paidBy,
    required this.participants,
    required this.splitType,
    required this.splitAmounts,
    required this.createdAt,
    this.groupId,
    this.notes = '',
    this.isFullySettled = false,
    this.settlements = const [],
  });

  factory SplitModel.fromMap(Map<String, dynamic> map) {
    return SplitModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      splitType: SplitType.values.firstWhere(
        (e) => e.toString() == map['splitType'],
        orElse: () => SplitType.equal,
      ),
      splitAmounts: Map<String, double>.from(
        (map['splitAmounts'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      groupId: map['groupId'],
      notes: map['notes'] ?? '',
      isFullySettled: map['isFullySettled'] ?? false,
      settlements:
          (map['settlements'] as List<dynamic>? ?? [])
              .map((e) => SettlementModel.fromMap(e))
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'totalAmount': totalAmount,
      'paidBy': paidBy,
      'participants': participants,
      'splitType': splitType.toString(),
      'splitAmounts': splitAmounts,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'groupId': groupId,
      'notes': notes,
      'isFullySettled': isFullySettled,
      'settlements': settlements.map((e) => e.toMap()).toList(),
    };
  }

  String get formattedTotalAmount => '₹${totalAmount.toInt()}';

  double getAmountOwedBy(String userId) {
    return splitAmounts[userId] ?? 0.0;
  }

  double getTotalSettledAmount(String userId) {
    return settlements
        .where((s) => s.fromUserId == userId)
        .fold(0.0, (sum, s) => sum + s.amount);
  }

  double getRemainingAmount(String userId) {
    return getAmountOwedBy(userId) - getTotalSettledAmount(userId);
  }
}

class SettlementModel {
  final String id;
  final String? splitId; // Make it nullable
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime settledAt;
  final String notes;

  SettlementModel({
    required this.id,
    this.splitId, // Optional
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.settledAt,
    this.notes = '',
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map) {
    return SettlementModel(
      id: map['id'] ?? '',
      splitId: map['splitId'], // Handle nullable
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      settledAt: DateTime.fromMillisecondsSinceEpoch(map['settledAt'] ?? 0),
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'splitId': splitId, // Include even if null
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'settledAt': settledAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  String get formattedAmount => '₹${amount.toInt()}';
}

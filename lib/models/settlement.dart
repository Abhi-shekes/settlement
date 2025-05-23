import 'package:cloud_firestore/cloud_firestore.dart';

class Settlement {
  final String id;
  final String expenseId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime settledAt;
  final bool isPartial;
  final String? note;

  Settlement({
    required this.id,
    required this.expenseId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.settledAt,
    this.isPartial = false,
    this.note,
  });

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Settlement(
      id: doc.id,
      expenseId: data['expenseId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      settledAt: (data['settledAt'] as Timestamp).toDate(),
      isPartial: data['isPartial'] ?? false,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'settledAt': Timestamp.fromDate(settledAt),
      'isPartial': isPartial,
      'note': note,
    };
  }
}

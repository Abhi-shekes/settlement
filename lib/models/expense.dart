import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String userId;
  final String? groupId;
  final Map<String, double>? splitDetails;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.userId,
    this.groupId,
    this.splitDetails,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    Map<String, double>? splitMap;
    if (data['splitDetails'] != null) {
      splitMap = Map<String, double>.from(data['splitDetails']);
    }
    
    return Expense(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? 'Other',
      userId: data['userId'] ?? '',
      groupId: data['groupId'],
      splitDetails: splitMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'userId': userId,
      'groupId': groupId,
      'splitDetails': splitDetails,
    };
  }
}

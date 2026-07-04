import 'expense_model.dart';

/// How often a recurring transaction repeats.
enum RecurrenceFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const RecurrenceFrequency(this.displayName);
  final String displayName;

  /// Returns the next occurrence after [from] for this frequency. Month/year
  /// steps clamp the day so e.g. a monthly rule on the 31st lands on the last
  /// day of shorter months.
  DateTime next(DateTime from) {
    switch (this) {
      case RecurrenceFrequency.daily:
        return DateTime(
          from.year,
          from.month,
          from.day + 1,
          from.hour,
          from.minute,
        );
      case RecurrenceFrequency.weekly:
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          from.hour,
          from.minute,
        );
      case RecurrenceFrequency.monthly:
        return _addMonths(from, 1);
      case RecurrenceFrequency.yearly:
        return _addMonths(from, 12);
    }
  }

  static DateTime _addMonths(DateTime from, int months) {
    final totalMonth = from.month - 1 + months;
    final year = from.year + totalMonth ~/ 12;
    final month = totalMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = from.day > lastDay ? lastDay : from.day;
    return DateTime(year, month, day, from.hour, from.minute);
  }
}

/// A rule that automatically creates an expense at a fixed interval — salary,
/// rent, subscriptions, EMIs, utility bills, etc. Set up once; the app records
/// the transaction on each scheduled date.
class RecurringTransactionModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount;
  final ExpenseCategory category;
  final String? accountId;
  final RecurrenceFrequency frequency;

  /// When the schedule begins.
  final DateTime startDate;

  /// The next date an expense should be generated for. Advances as occurrences
  /// are processed.
  final DateTime nextDueDate;

  /// Last date an expense was actually generated, if any.
  final DateTime? lastRunDate;

  /// Optional end date; no occurrences are generated after it.
  final DateTime? endDate;

  final bool isActive;
  final DateTime createdAt;

  RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.lastRunDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory RecurringTransactionModel.fromMap(Map<String, dynamic> map) {
    return RecurringTransactionModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString() == map['category'],
        orElse: () => ExpenseCategory.other,
      ),
      accountId: map['accountId'],
      frequency: RecurrenceFrequency.values.firstWhere(
        (f) => f.name == map['frequency'],
        orElse: () => RecurrenceFrequency.monthly,
      ),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
      nextDueDate: DateTime.fromMillisecondsSinceEpoch(map['nextDueDate'] ?? 0),
      lastRunDate:
          map['lastRunDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['lastRunDate'])
              : null,
      endDate:
          map['endDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
              : null,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
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
      'accountId': accountId,
      'frequency': frequency.name,
      'startDate': startDate.millisecondsSinceEpoch,
      'nextDueDate': nextDueDate.millisecondsSinceEpoch,
      'lastRunDate': lastRunDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  RecurringTransactionModel copyWith({
    String? title,
    String? description,
    double? amount,
    ExpenseCategory? category,
    String? accountId,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? nextDueDate,
    DateTime? lastRunDate,
    DateTime? endDate,
    bool? isActive,
    bool clearAccount = false,
    bool clearEndDate = false,
    bool clearLastRun = false,
  }) {
    return RecurringTransactionModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastRunDate: clearLastRun ? null : (lastRunDate ?? this.lastRunDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  String get formattedAmount => '₹${amount.toInt()}';
}

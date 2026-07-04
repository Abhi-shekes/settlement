import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../models/expense_model.dart';
import 'expense_service.dart';

/// Manages recurring transaction rules and materialises the expenses they're
/// due for. Processing runs when the app opens ([processDue]): any occurrence
/// whose date has passed is turned into a real expense (via [ExpenseService] so
/// account balances and reports update through the normal path), and the rule's
/// next-due date is advanced and persisted so nothing is generated twice.
class RecurringService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Safety cap so a mis-set start date far in the past can't spawn thousands
  /// of expenses in one pass.
  static const int _maxOccurrencesPerRun = 60;

  List<RecurringTransactionModel> _rules = [];
  List<RecurringTransactionModel> get rules => _rules;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ExpenseService? _expenseService;
  void attachExpenseService(ExpenseService expenseService) {
    _expenseService = expenseService;
  }

  void reset() {
    _rules = [];
    notifyListeners();
  }

  Future<void> loadUserRecurring() async {
    if (_auth.currentUser == null) return;
    try {
      _isLoading = true;
      notifyListeners();

      final query =
          await _firestore
              .collection('recurring_transactions')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .orderBy('nextDueDate', descending: false)
              .get();

      _rules =
          query.docs
              .map((doc) => RecurringTransactionModel.fromMap(doc.data()))
              .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading recurring transactions: $e');
    }
  }

  Future<void> addRule(RecurringTransactionModel rule) async {
    try {
      await _firestore
          .collection('recurring_transactions')
          .doc(rule.id)
          .set(rule.toMap());
      _rules.add(rule);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding recurring rule: $e');
      rethrow;
    }
  }

  Future<void> updateRule(RecurringTransactionModel rule) async {
    try {
      await _firestore
          .collection('recurring_transactions')
          .doc(rule.id)
          .update(rule.toMap());
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index != -1) _rules[index] = rule;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating recurring rule: $e');
      rethrow;
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      await _firestore
          .collection('recurring_transactions')
          .doc(ruleId)
          .delete();
      _rules.removeWhere((r) => r.id == ruleId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting recurring rule: $e');
      rethrow;
    }
  }

  Future<void> toggleActive(RecurringTransactionModel rule) async {
    await updateRule(rule.copyWith(isActive: !rule.isActive));
  }

  /// Generates any past-due expenses for all active rules and advances their
  /// schedules. Safe to call on every app open; a no-op when nothing is due.
  /// Loads the rules first if they haven't been loaded yet.
  Future<void> processDue() async {
    if (_auth.currentUser == null) return;
    if (_rules.isEmpty) await loadUserRecurring();

    final now = DateTime.now();
    var didWork = false;

    for (var i = 0; i < _rules.length; i++) {
      var rule = _rules[i];
      if (!rule.isActive) continue;

      var next = rule.nextDueDate;
      DateTime? lastRun = rule.lastRunDate;
      var generated = 0;

      while (!next.isAfter(now) &&
          (rule.endDate == null || !next.isAfter(rule.endDate!)) &&
          generated < _maxOccurrencesPerRun) {
        await _createOccurrence(rule, next);
        lastRun = next;
        next = rule.frequency.next(next);
        generated++;
      }

      if (generated > 0) {
        rule = rule.copyWith(nextDueDate: next, lastRunDate: lastRun);
        // Persist the advanced schedule so occurrences aren't regenerated.
        await _firestore
            .collection('recurring_transactions')
            .doc(rule.id)
            .update({
              'nextDueDate': rule.nextDueDate.millisecondsSinceEpoch,
              'lastRunDate': rule.lastRunDate?.millisecondsSinceEpoch,
            });
        _rules[i] = rule;
        didWork = true;
      }
    }

    if (didWork) notifyListeners();
  }

  Future<void> _createOccurrence(
    RecurringTransactionModel rule,
    DateTime date,
  ) async {
    final expense = ExpenseModel(
      id: const Uuid().v4(),
      userId: rule.userId,
      title: rule.title,
      description: rule.description,
      amount: rule.amount,
      category: rule.category,
      createdAt: date,
      accountId: rule.accountId,
      recurringId: rule.id,
    );
    // Route through ExpenseService so the account balance is adjusted and the
    // in-memory expense list/reports stay in sync.
    if (_expenseService != null) {
      await _expenseService!.addExpense(expense);
    } else {
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());
    }
  }

  List<RecurringTransactionModel> get activeRules =>
      _rules.where((r) => r.isActive).toList();
}

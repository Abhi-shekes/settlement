import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_model.dart';
import 'account_service.dart';

class ExpenseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> get expenses => _expenses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Injected (via ChangeNotifierProxyProvider) so that expenses tied to an
  /// account keep that account's balance in sync as they are added, edited, or
  /// deleted. Kept as a dependency rather than adjusting balances at each call
  /// site so the logic lives in one place and can't drift.
  AccountService? _accountService;
  void attachAccountService(AccountService accountService) {
    _accountService = accountService;
  }

  /// Clears cached data (e.g. on sign-out) so the next user never sees the
  /// previous account's expenses.
  void reset() {
    _expenses = [];
    notifyListeners();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());
      _expenses.add(expense);

      // Spending reduces the paying account's balance.
      if (expense.accountId != null) {
        await _accountService?.adjustBalance(
          expense.accountId!,
          -expense.amount,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> loadUserExpenses() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final query =
          await _firestore
              .collection('expenses')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .orderBy('createdAt', descending: true)
              .get();

      // Personal expense tracking excludes group expenses: a group expense is
      // recorded under the payer's userId, but the payer only owes their share
      // (tracked via the group split), so counting the full amount here would
      // double-count it in personal totals and budgets.
      _expenses =
          query.docs
              .map((doc) => ExpenseModel.fromMap(doc.data()))
              .where((e) => e.groupId == null)
              .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading expenses: $e');
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      final old = index != -1 ? _expenses[index] : null;

      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .update(expense.toMap());

      // Keep account balances in sync: undo the old charge, then apply the new
      // one. Correct even when the amount or the account itself changed.
      if (old?.accountId != null) {
        await _accountService?.adjustBalance(old!.accountId!, old.amount);
      }
      if (expense.accountId != null) {
        await _accountService?.adjustBalance(
          expense.accountId!,
          -expense.amount,
        );
      }

      if (index != -1) {
        _expenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      final removed = index != -1 ? _expenses[index] : null;

      await _firestore.collection('expenses').doc(expenseId).delete();
      _expenses.removeWhere((e) => e.id == expenseId);

      // Refund the account for the deleted charge.
      if (removed?.accountId != null) {
        await _accountService?.adjustBalance(
          removed!.accountId!,
          removed.amount,
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }

  /// Records a refund/reversal of [original] for [amount] (a positive rupee
  /// value). Stored as a linked expense with a negative amount so it credits
  /// the account and reduces spending totals/budgets through the normal paths.
  /// Credits [accountId] if given, otherwise the original expense's account.
  Future<void> recordRefund(
    ExpenseModel original, {
    required double amount,
    String? accountId,
    String? note,
  }) async {
    if (_auth.currentUser == null) return;

    final refund = ExpenseModel(
      id: '${original.id}-refund-${DateTime.now().millisecondsSinceEpoch}',
      userId: _auth.currentUser!.uid,
      title: 'Refund: ${original.title}',
      description:
          note?.trim().isNotEmpty == true
              ? note!.trim()
              : 'Refund/reversal of "${original.title}"',
      amount: -amount.abs(),
      category: original.category,
      createdAt: DateTime.now(),
      accountId: accountId ?? original.accountId,
      refundOfExpenseId: original.id,
    );

    await addExpense(refund);
  }

  /// All refund records linked to [expenseId].
  List<ExpenseModel> getRefundsFor(String expenseId) {
    return _expenses.where((e) => e.refundOfExpenseId == expenseId).toList();
  }

  /// Total amount already refunded against [expenseId] (positive rupees).
  double totalRefundedFor(String expenseId) {
    return getRefundsFor(expenseId).fold(0.0, (acc, r) => acc + r.amount.abs());
  }

  List<ExpenseModel> getExpensesByCategory(ExpenseCategory category) {
    return _expenses.where((e) => e.category == category).toList();
  }

  List<ExpenseModel> getExpensesByDateRange(DateTime start, DateTime end) {
    // [start, end): include the exact start instant (e.g. midnight) so an
    // expense created at 00:00:00.000 is not dropped from its own day.
    return _expenses
        .where((e) => !e.createdAt.isBefore(start) && e.createdAt.isBefore(end))
        .toList();
  }

  List<ExpenseModel> getTopExpenses(int count) {
    final sorted = List<ExpenseModel>.from(_expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(count).toList();
  }

  double getTotalExpenseAmount() {
    return _expenses.fold(0.0, (acc, expense) => acc + expense.amount);
  }

  double getTotalExpenseAmountByCategory(ExpenseCategory category) {
    return getExpensesByCategory(
      category,
    ).fold(0.0, (acc, expense) => acc + expense.amount);
  }

  Map<ExpenseCategory, double> getCategoryWiseExpenses() {
    final Map<ExpenseCategory, double> categoryExpenses = {};

    for (final category in ExpenseCategory.values) {
      categoryExpenses[category] = getTotalExpenseAmountByCategory(category);
    }

    return categoryExpenses;
  }

  List<ExpenseModel> searchExpenses(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _expenses
        .where(
          (expense) =>
              expense.title.toLowerCase().contains(lowercaseQuery) ||
              expense.description.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  }

  // Analytics methods
  Map<String, double> getDailyExpenses(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dailyExpenses = getExpensesByDateRange(startOfDay, endOfDay);
    final Map<String, double> hourlyData = {};

    for (final expense in dailyExpenses) {
      final hour = '${expense.createdAt.hour}:00';
      hourlyData[hour] = (hourlyData[hour] ?? 0) + expense.amount;
    }

    return hourlyData;
  }

  Map<String, double> getWeeklyExpenses(DateTime weekStart) {
    final Map<String, double> weeklyData = {};

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayName = _getDayName(day.weekday);
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dailyExpenses = getExpensesByDateRange(startOfDay, endOfDay);
      weeklyData[dayName] = dailyExpenses.fold(0.0, (acc, e) => acc + e.amount);
    }

    return weeklyData;
  }

  Map<String, double> getMonthlyExpenses(DateTime month) {
    final Map<String, double> monthlyData = {};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int i = 1; i <= daysInMonth; i++) {
      final day = DateTime(month.year, month.month, i);
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dailyExpenses = getExpensesByDateRange(startOfDay, endOfDay);
      monthlyData['$i'] = dailyExpenses.fold(0.0, (acc, e) => acc + e.amount);
    }

    return monthlyData;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}

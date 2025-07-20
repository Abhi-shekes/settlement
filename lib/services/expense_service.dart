import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_model.dart';

class ExpenseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> get expenses => _expenses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());
      _expenses.add(expense);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error adding expense: $e');
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

      _expenses =
          query.docs.map((doc) => ExpenseModel.fromMap(doc.data())).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading expenses: $e');
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .update(expense.toMap());

      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).delete();
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }

  List<ExpenseModel> getExpensesByCategory(ExpenseCategory category) {
    return _expenses.where((e) => e.category == category).toList();
  }

  List<ExpenseModel> getExpensesByDateRange(DateTime start, DateTime end) {
    return _expenses
        .where((e) => e.createdAt.isAfter(start) && e.createdAt.isBefore(end))
        .toList();
  }

  List<ExpenseModel> getTopExpenses(int count) {
    final sorted = List<ExpenseModel>.from(_expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(count).toList();
  }

  double getTotalExpenseAmount() {
    return _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double getTotalExpenseAmountByCategory(ExpenseCategory category) {
    return getExpensesByCategory(
      category,
    ).fold(0.0, (sum, expense) => sum + expense.amount);
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
      weeklyData[dayName] = dailyExpenses.fold(0.0, (sum, e) => sum + e.amount);
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
      monthlyData['$i'] = dailyExpenses.fold(0.0, (sum, e) => sum + e.amount);
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

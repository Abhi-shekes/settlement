import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../models/expense_model.dart';

class BudgetService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<BudgetModel> _budgets = [];
  List<BudgetModel> get budgets => _budgets;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // Near limit threshold (percentage)
  final double _nearLimitThreshold = 0.8; // 80%
  
  // Load user budgets for the current month
  Future<void> loadUserBudgets() async {
    if (_auth.currentUser == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      // Get the first day of the current month
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);
      
      final query = await _firestore
          .collection('budgets')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('month', isEqualTo: currentMonth.millisecondsSinceEpoch)
          .get();
      
      _budgets = query.docs
          .map((doc) => BudgetModel.fromMap(doc.data()))
          .toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading budgets: $e');
    }
  }
  
  // Set or update a budget for a category
  Future<void> setBudget(ExpenseCategory category, double amount) async {
    if (_auth.currentUser == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);
      
      // Check if budget already exists for this category and month
      final existingBudget = _budgets.firstWhere(
        (b) => b.category == category && 
               b.month.year == currentMonth.year && 
               b.month.month == currentMonth.month,
        orElse: () => BudgetModel(
          id: const Uuid().v4(),
          userId: _auth.currentUser!.uid,
          category: category,
          amount: 0,
          month: currentMonth,
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      final updatedBudget = existingBudget.copyWith(
        amount: amount,
        updatedAt: now,
      );
      
      await _firestore
          .collection('budgets')
          .doc(updatedBudget.id)
          .set(updatedBudget.toMap());
      
      // Update local list
      final index = _budgets.indexWhere((b) => b.id == updatedBudget.id);
      if (index >= 0) {
        _budgets[index] = updatedBudget;
      } else {
        _budgets.add(updatedBudget);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error setting budget: $e');
      rethrow;
    }
  }
  
  // Delete a budget
  Future<void> deleteBudget(String budgetId) async {
    try {
      await _firestore.collection('budgets').doc(budgetId).delete();
      _budgets.removeWhere((b) => b.id == budgetId);
      notifyListeners();
    } catch (e) {
      print('Error deleting budget: $e');
      rethrow;
    }
  }
  
  // Get budget for a specific category in the current month
  BudgetModel? getBudgetForCategory(ExpenseCategory category) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    
    return _budgets.firstWhere(
      (b) => b.category == category && 
             b.month.year == currentMonth.year && 
             b.month.month == currentMonth.month,
      orElse: () => BudgetModel(
        id: const Uuid().v4(),
        userId: _auth.currentUser?.uid ?? '',
        category: category,
        amount: 0, // No budget set
        month: currentMonth,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  
  // Check if a category has exceeded its budget
  bool isBudgetExceeded(ExpenseCategory category, double currentSpending) {
    final budget = getBudgetForCategory(category);
    if (budget == null || budget.amount <= 0) return false; // No budget set
    
    return currentSpending > budget.amount;
  }
  
  // Check if a category is nearing its budget limit
  bool isBudgetNearLimit(ExpenseCategory category, double currentSpending) {
    final budget = getBudgetForCategory(category);
    if (budget == null || budget.amount <= 0) return false; // No budget set
    
    return currentSpending >= (budget.amount * _nearLimitThreshold) && 
           currentSpending <= budget.amount;
  }
  
  // Calculate budget usage percentage
  double getBudgetUsagePercentage(ExpenseCategory category, double currentSpending) {
    final budget = getBudgetForCategory(category);
    if (budget == null || budget.amount <= 0) return 0.0; // No budget set
    
    return (currentSpending / budget.amount) * 100;
  }
  
  // Get remaining budget amount
  double getRemainingBudget(ExpenseCategory category, double currentSpending) {
    final budget = getBudgetForCategory(category);
    if (budget == null || budget.amount <= 0) return 0.0; // No budget set
    
    return budget.amount - currentSpending;
  }
  
  // Get all categories with budgets
  List<ExpenseCategory> getCategoriesWithBudgets() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    
    return _budgets
        .where((b) => b.month.year == currentMonth.year && 
                      b.month.month == currentMonth.month && 
                      b.amount > 0)
        .map((b) => b.category)
        .toList();
  }
  
  // Check if any budget is exceeded after adding a new expense
  Map<String, dynamic>? checkBudgetExceeded(
    ExpenseCategory category, 
    double amount, 
    double currentCategorySpending
  ) {
    final newSpending = currentCategorySpending + amount;
    final budget = getBudgetForCategory(category);
    
    if (budget == null || budget.amount <= 0) return null; // No budget set
    
    if (newSpending > budget.amount) {
      // Budget exceeded
      return {
        'category': category,
        'budgetAmount': budget.amount,
        'currentSpending': currentCategorySpending,
        'newSpending': newSpending,
        'exceededBy': newSpending - budget.amount,
        'percentage': (newSpending / budget.amount) * 100,
      };
    } else if (newSpending >= (budget.amount * _nearLimitThreshold) && 
               currentCategorySpending < (budget.amount * _nearLimitThreshold)) {
      // Approaching budget limit (crossed threshold with this expense)
      return {
        'category': category,
        'budgetAmount': budget.amount,
        'currentSpending': currentCategorySpending,
        'newSpending': newSpending,
        'remainingBudget': budget.amount - newSpending,
        'percentage': (newSpending / budget.amount) * 100,
        'isApproaching': true,
      };
    }
    
    return null; // Budget not exceeded or approaching
  }
}

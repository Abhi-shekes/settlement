import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/budget_service.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final Map<ExpenseCategory, TextEditingController> _controllers = {};
  
  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadBudgets();
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _initControllers() {
    for (final category in ExpenseCategory.values) {
      _controllers[category] = TextEditingController();
    }
  }
  
  Future<void> _loadBudgets() async {
    await context.read<BudgetService>().loadUserBudgets();
    
    // Set controller values from loaded budgets
    final budgetService = context.read<BudgetService>();
    for (final category in ExpenseCategory.values) {
      final budget = budgetService.getBudgetForCategory(category);
      if (budget != null && budget.amount > 0) {
        _controllers[category]!.text = budget.amount.toString();
      } else {
        _controllers[category]!.text = '';
      }
    }
  }
  
  Future<void> _saveBudget(ExpenseCategory category, String value) async {
    if (value.isEmpty) return;
    
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) return;
    
    try {
      await context.read<BudgetService>().setBudget(category, amount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget for ${category.toString().split('.').last.toUpperCase()} updated'),
          backgroundColor: const Color(0xFF008080),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating budget: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: Consumer2<BudgetService, ExpenseService>(
        builder: (context, budgetService, expenseService, child) {
          if (budgetService.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF008080)));
          }
          
          // Get current month for display
          final now = DateTime.now();
          final currentMonth = DateFormat('MMMM yyyy').format(now);
          
          return RefreshIndicator(
            onRefresh: _loadBudgets,
            color: const Color(0xFF008080),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF008080), Color(0xFF20B2AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Monthly Budget',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentMonth,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Budget Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Text(
                              'How Budgeting Works',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Set monthly budgets for each expense category\n'
                          '• Get alerts when you exceed your budget\n'
                          '• Receive notifications when nearing budget limits (80%)\n'
                          '• Leave a budget empty or set to 0 to disable tracking',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Category Budgets
                  const Text(
                    'Category Budgets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008080),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ...ExpenseCategory.values.map((category) {
                    final currentSpending = expenseService.getTotalExpenseAmountByCategory(category);
                    final budget = budgetService.getBudgetForCategory(category);
                    final budgetAmount = budget?.amount ?? 0;
                    
                    // Calculate usage percentage
                    double usagePercentage = 0;
                    if (budgetAmount > 0) {
                      usagePercentage = (currentSpending / budgetAmount) * 100;
                      if (usagePercentage > 100) usagePercentage = 100;
                    }
                    
                    // Determine progress color based on usage
                    Color progressColor;
                    if (budgetAmount > 0 && currentSpending > budgetAmount) {
                      progressColor = Colors.red;
                    } else if (budgetAmount > 0 && currentSpending >= budgetAmount * 0.8) {
                      progressColor = Colors.orange;
                    } else {
                      progressColor = const Color(0xFF008080);
                    }
                    
                    return _buildBudgetCard(
                      category,
                      _controllers[category]!,
                      currentSpending,
                      budgetAmount,
                      usagePercentage,
                      progressColor,
                    );
                  }).toList(),
                  
                  const SizedBox(height: 24),
                  
                  // Save All Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Save all budgets
                        for (final entry in _controllers.entries) {
                          final value = entry.value.text.trim();
                          if (value.isNotEmpty) {
                            await _saveBudget(entry.key, value);
                          }
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All budgets updated successfully'),
                            backgroundColor: Color(0xFF008080),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008080),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save All Budgets',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildBudgetCard(
    ExpenseCategory category,
    TextEditingController controller,
    double currentSpending,
    double budgetAmount,
    double usagePercentage,
    Color progressColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (budgetAmount > 0 && currentSpending > budgetAmount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'EXCEEDED',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (budgetAmount > 0 && currentSpending >= budgetAmount * 0.8 && currentSpending <= budgetAmount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEAR LIMIT',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Budget Input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Monthly Budget',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          hintText: 'Enter amount',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (value) => _saveBudget(category, value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Spending',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹ ${currentSpending.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Budget Progress
            if (budgetAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Used: ${usagePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: progressColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    budgetAmount > currentSpending
                        ? 'Remaining: ₹${(budgetAmount - currentSpending).toStringAsFixed(2)}'
                        : 'Exceeded by: ₹${(currentSpending - budgetAmount).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: budgetAmount > currentSpending ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: progressColor,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.travel:
        return Icons.directions_car;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.utilities:
        return Icons.lightbulb;
      case ExpenseCategory.healthcare:
        return Icons.medical_services;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.other:
        return Icons.category;
    }
  }
  
  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Colors.orange;
      case ExpenseCategory.travel:
        return Colors.blue;
      case ExpenseCategory.shopping:
        return Colors.purple;
      case ExpenseCategory.entertainment:
        return Colors.red;
      case ExpenseCategory.utilities:
        return Colors.amber;
      case ExpenseCategory.healthcare:
        return Colors.green;
      case ExpenseCategory.education:
        return Colors.indigo;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }
}

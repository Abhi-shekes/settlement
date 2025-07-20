import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../widgets/budget_alert_dialog.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load budgets when screen initializes
    context.read<BudgetService>().loadUserBudgets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final expenseService = context.read<ExpenseService>();
    final budgetService = context.read<BudgetService>();

    if (authService.currentUser == null) return;

    // Get amount from controller
    final amount = double.parse(_amountController.text);

    // Check if this expense will exceed budget
    final currentCategorySpending = expenseService
        .getTotalExpenseAmountByCategory(_selectedCategory);
    final budgetCheck = budgetService.checkBudgetExceeded(
      _selectedCategory,
      amount,
      currentCategorySpending,
    );

    // Create the expense
    final expense = ExpenseModel(
      id: const Uuid().v4(),
      userId: authService.currentUser!.uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      createdAt: DateTime.now(),
    );

    try {
      // Save the expense
      await expenseService.addExpense(expense);

      if (mounted) {
        // Show budget alert if needed
        if (budgetCheck != null) {
          // Show different alerts for exceeded vs approaching
          if (budgetCheck.containsKey('isApproaching') &&
              budgetCheck['isApproaching']) {
            // Approaching budget limit
            showDialog(
              context: context,
              builder:
                  (context) => BudgetAlertDialog(
                    category: budgetCheck['category'],
                    budgetAmount: budgetCheck['budgetAmount'],
                    currentSpending: budgetCheck['currentSpending'],
                    newSpending: budgetCheck['newSpending'],
                    exceededBy: 0, // Not exceeded yet
                    percentage: budgetCheck['percentage'],
                    isApproaching: true,
                  ),
            );
          } else {
            // Exceeded budget
            showDialog(
              context: context,
              builder:
                  (context) => BudgetAlertDialog(
                    category: budgetCheck['category'],
                    budgetAmount: budgetCheck['budgetAmount'],
                    currentSpending: budgetCheck['currentSpending'],
                    newSpending: budgetCheck['newSpending'],
                    exceededBy: budgetCheck['exceededBy'],
                    percentage: budgetCheck['percentage'],
                  ),
            );
          }
        } else {
          // No budget issues, just show success message
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added successfully!'),
              backgroundColor: Color(0xFF008080),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding expense: $e'),
            backgroundColor: const Color(0xFFFF7F50),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Expense Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<ExpenseCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items:
                    ExpenseCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category.toString().split('.').last.toUpperCase(),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Budget Info
              Consumer2<BudgetService, ExpenseService>(
                builder: (context, budgetService, expenseService, child) {
                  final budget = budgetService.getBudgetForCategory(
                    _selectedCategory,
                  );
                  final currentSpending = expenseService
                      .getTotalExpenseAmountByCategory(_selectedCategory);

                  if (budget != null && budget.amount > 0) {
                    // Calculate usage percentage
                    final usagePercentage =
                        (currentSpending / budget.amount) * 100;

                    return Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Budget Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      usagePercentage > 100
                                          ? Colors.red.withOpacity(0.1)
                                          : usagePercentage >= 80
                                          ? Colors.orange.withOpacity(0.1)
                                          : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  usagePercentage > 100
                                      ? 'Exceeded'
                                      : usagePercentage >= 80
                                      ? 'Near Limit'
                                      : 'On Track',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        usagePercentage > 100
                                            ? Colors.red
                                            : usagePercentage >= 80
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monthly Budget: ${budget.formattedAmount}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Spent: ₹${currentSpending.toInt()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value:
                                  usagePercentage > 100
                                      ? 1.0
                                      : usagePercentage / 100,
                              backgroundColor: Colors.grey[200],
                              color:
                                  usagePercentage > 100
                                      ? Colors.red
                                      : usagePercentage >= 80
                                      ? Colors.orange
                                      : const Color(0xFF008080),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adding this expense might ${usagePercentage > 100
                                ? 'further exceed'
                                : usagePercentage >= 80
                                ? 'exceed'
                                : 'affect'} your budget.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008080),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Add Expense',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

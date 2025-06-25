import 'package:flutter/material.dart';
import '../models/expense_model.dart';

class BudgetProgressCard extends StatelessWidget {
  final ExpenseCategory category;
  final double budgetAmount;
  final double currentSpending;
  final VoidCallback onTap;

  const BudgetProgressCard({
    super.key,
    required this.category,
    required this.budgetAmount,
    required this.currentSpending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
              
              // Budget Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Budget',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${budgetAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Spent',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${currentSpending.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: progressColor,
                  minHeight: 8,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Usage Percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${usagePercentage.toStringAsFixed(1)}% used',
                    style: TextStyle(
                      fontSize: 12,
                      color: progressColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (budgetAmount > 0)
                    Text(
                      budgetAmount > currentSpending
                          ? 'Remaining: ₹${(budgetAmount - currentSpending).toStringAsFixed(2)}'
                          : 'Exceeded: ₹${(currentSpending - budgetAmount).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: budgetAmount > currentSpending ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
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

import 'package:flutter/material.dart';
import '../models/expense_model.dart';

class BudgetAlertDialog extends StatelessWidget {
  final ExpenseCategory category;
  final double budgetAmount;
  final double currentSpending;
  final double newSpending;
  final double exceededBy;
  final double percentage;
  final bool isApproaching;

  const BudgetAlertDialog({
    super.key,
    required this.category,
    required this.budgetAmount,
    required this.currentSpending,
    required this.newSpending,
    required this.exceededBy,
    required this.percentage,
    this.isApproaching = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isApproaching 
                    ? Colors.orange.withOpacity(0.1) 
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isApproaching ? Icons.warning_amber : Icons.error_outline,
                color: isApproaching ? Colors.orange : Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            
            // Alert Title
            Text(
              isApproaching 
                  ? 'Approaching Budget Limit' 
                  : 'Budget Exceeded',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isApproaching ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            
            // Category
            Text(
              category.toString().split('.').last.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // Budget Details
            _buildDetailRow('Budget Amount:', '₹${budgetAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildDetailRow('Current Spending:', '₹${newSpending.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildDetailRow(
              isApproaching ? 'Remaining:' : 'Exceeded By:',
              isApproaching 
                  ? '₹${(budgetAmount - newSpending).toStringAsFixed(2)}' 
                  : '₹${exceededBy.toStringAsFixed(2)}',
              isApproaching ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Usage:',
              '${percentage.toStringAsFixed(1)}%',
              isApproaching ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage > 100 ? 1.0 : percentage / 100,
                backgroundColor: Colors.grey.shade200,
                color: isApproaching ? Colors.orange : Colors.red,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 24),
            
            // Message
            Text(
              isApproaching
                  ? 'You\'re approaching your monthly budget limit for this category. Consider reducing expenses to stay within budget.'
                  : 'You\'ve exceeded your monthly budget for this category. Consider adjusting your budget or reducing expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/budgets');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008080),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Adjust Budget'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

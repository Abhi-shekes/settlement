import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/budget_service.dart';
import '../../services/expense_service.dart';
import '../../widgets/budget_progress_card.dart';
import 'budget_screen.dart';

class BudgetOverviewScreen extends StatefulWidget {
  const BudgetOverviewScreen({super.key});

  @override
  State<BudgetOverviewScreen> createState() => _BudgetOverviewScreenState();
}

class _BudgetOverviewScreenState extends State<BudgetOverviewScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<BudgetService>().loadUserBudgets(),
      context.read<ExpenseService>().loadUserExpenses(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Overview'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetScreen()),
              );
            },
            tooltip: 'Set Budgets',
          ),
        ],
      ),
      body: Consumer2<BudgetService, ExpenseService>(
        builder: (context, budgetService, expenseService, child) {
          if (budgetService.isLoading || expenseService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF008080)),
            );
          }

          // Get categories with budgets
          final categoriesWithBudgets =
              budgetService.getCategoriesWithBudgets();

          // If no budgets are set, show empty state
          if (categoriesWithBudgets.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF008080),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget Summary
                  _buildBudgetSummary(budgetService, expenseService),

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

                  // Budget Progress Cards
                  ...categoriesWithBudgets.map((category) {
                    final budget = budgetService.getBudgetForCategory(category);
                    final currentSpending = expenseService
                        .getTotalExpenseAmountByCategory(category);

                    return BudgetProgressCard(
                      category: category,
                      budgetAmount: budget?.amount ?? 0,
                      currentSpending: currentSpending,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BudgetScreen(),
                          ),
                        );
                      },
                    );
                  }).toList(),

                  const SizedBox(height: 24),

                  // Add Budget Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BudgetScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Manage Budgets'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: const Color(0xFF008080),
                        side: const BorderSide(color: Color(0xFF008080)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No budgets set',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set budgets to track your spending',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Set Budgets'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary(
    BudgetService budgetService,
    ExpenseService expenseService,
  ) {
    // Get categories with budgets
    final categoriesWithBudgets = budgetService.getCategoriesWithBudgets();

    // Calculate total budget and spending
    double totalBudget = 0;
    double totalSpending = 0;

    for (final category in categoriesWithBudgets) {
      final budget = budgetService.getBudgetForCategory(category);
      final spending = expenseService.getTotalExpenseAmountByCategory(category);

      if (budget != null) {
        totalBudget += budget.amount;
      }

      totalSpending += spending;
    }

    // Calculate overall usage percentage
    double overallPercentage = 0;
    if (totalBudget > 0) {
      overallPercentage = (totalSpending / totalBudget) * 100;
      if (overallPercentage > 100) overallPercentage = 100;
    }

    // Determine overall status
    String status;
    Color statusColor;

    if (totalBudget > 0 && totalSpending > totalBudget) {
      status = 'Over Budget';
      statusColor = Colors.red;
    } else if (totalBudget > 0 && totalSpending >= totalBudget * 0.8) {
      status = 'Near Limit';
      statusColor = Colors.orange;
    } else {
      status = 'On Track';
      statusColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF008080), Color(0xFF20B2AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Budget Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Budget vs Spending
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total Budget', '₹${totalBudget.toInt()}'),
              _buildSummaryItem('Total Spent', '₹${totalSpending.toInt()}'),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallPercentage / 100,
              backgroundColor: Colors.white.withOpacity(0.2),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // Usage Percentage and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${overallPercentage.toInt()}% used',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

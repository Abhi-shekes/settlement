import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/group_service.dart';
import '../../services/budget_service.dart';

import '../../widgets/budget_progress_card.dart';
import '../expenses/add_expense_screen.dart';
import '../splits/add_split_screen.dart';
import '../groups/create_group_screen.dart';
import '../budgets/budget_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<ExpenseService>().loadUserExpenses(),
      context.read<GroupService>().loadUserGroups(),
      context.read<GroupService>().loadUserSplits(),
      context.read<BudgetService>().loadUserBudgets(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF008080),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: 24),

              // Financial Overview Cards
              _buildFinancialOverview(),
              const SizedBox(height: 24),

              // Budget Alerts
              _buildBudgetAlerts(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Recent Activity
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
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
              Text(
                'Welcome back,',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                authService.currentUser?.displayName?.split(' ').first ??
                    'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here\'s your financial overview',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialOverview() {
    return Consumer2<ExpenseService, GroupService>(
      builder: (context, expenseService, groupService, child) {
        final currentUserId =
            context.read<AuthService>().currentUser?.uid ?? '';

        // Calculate totals
        final totalExpenses = expenseService.getTotalExpenseAmount();
        final totalOwed = groupService.getTotalAmountOwed(currentUserId);
        final totalOwing = groupService.getTotalAmountOwing(currentUserId);
        final netBalance = totalOwing - totalOwed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF008080),
              ),
            ),
            const SizedBox(height: 16),

            // Main Balance Cards
            Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    'Total Expenses',
                    '₹${totalExpenses.toInt()}',
                    Icons.receipt_long,
                    const Color(0xFF008080),
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceCard(
                    'Net Balance',
                    netBalance >= 0
                        ? '+₹${netBalance.toInt()}'
                        : '-₹${(-netBalance).toInt()}',
                    netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                    netBalance >= 0 ? Colors.green : const Color(0xFFFF7F50),
                    Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Owe Cards
            Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    'You Owe',
                    '₹${totalOwed.toInt()}',
                    Icons.arrow_upward,
                    const Color(0xFFFF7F50),
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceCard(
                    'Owed to You',
                    '₹${totalOwing.toInt()}',
                    Icons.arrow_downward,
                    Colors.green,
                    Colors.white,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBudgetAlerts() {
    return Consumer2<BudgetService, ExpenseService>(
      builder: (context, budgetService, expenseService, child) {
        // Get categories with budgets
        final categoriesWithBudgets = budgetService.getCategoriesWithBudgets();

        // Filter to only show categories that are near limit or exceeded
        final alertCategories =
            categoriesWithBudgets.where((category) {
              final currentSpending = expenseService
                  .getTotalExpenseAmountByCategory(category);
              final budget = budgetService.getBudgetForCategory(category);

              if (budget == null || budget.amount <= 0) return false;

              return currentSpending >=
                  budget.amount * 0.8; // 80% or more of budget
            }).toList();

        if (alertCategories.isEmpty) {
          return const SizedBox.shrink(); // No alerts to show
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Budget Alerts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BudgetScreen(),
                      ),
                    );
                  },
                  child: const Text('Manage Budgets'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Alert Cards
            ...alertCategories.map((category) {
              final currentSpending = expenseService
                  .getTotalExpenseAmountByCategory(category);
              final budget = budgetService.getBudgetForCategory(category);

              if (budget == null) return const SizedBox.shrink();

              return BudgetProgressCard(
                category: category,
                budgetAmount: budget.amount,
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
          ],
        );
      },
    );
  }

  Widget _buildBalanceCard(
    String title,
    String amount,
    IconData icon,
    Color color,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: textColor, size: 24),
              if (title == 'Net Balance')
                Icon(
                  amount.startsWith('+')
                      ? Icons.sentiment_satisfied
                      : Icons.sentiment_dissatisfied,
                  color: textColor,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF008080),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Add Expense',
                'Track personal spending',
                Icons.add_circle,
                const Color(0xFF008080),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddExpenseScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Split Bill',
                'Share expenses with friends',
                Icons.call_split,
                const Color(0xFFFF7F50),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSplitScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Create Group',
                'Manage group expenses',
                Icons.group_add,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Set Budgets',
                'Manage category budgets',
                Icons.account_balance_wallet,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BudgetScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF008080),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Consumer2<ExpenseService, GroupService>(
      builder: (context, expenseService, groupService, child) {
        // Combine recent expenses and splits
        final recentExpenses = expenseService.expenses.take(3).toList();
        final recentSplits = groupService.splits.take(3).toList();

        // Create a combined list with timestamps for sorting
        final List<ActivityItem> activities = [];

        for (final expense in recentExpenses) {
          activities.add(
            ActivityItem(
              type: ActivityType.personalExpense,
              title: expense.title,
              amount: expense.amount,
              date: expense.createdAt,
              icon: Icons.receipt,
              color: const Color(0xFF008080),
              subtitle: expense.categoryDisplayName,
            ),
          );
        }

        for (final split in recentSplits) {
          final currentUserId =
              context.read<AuthService>().currentUser?.uid ?? '';
          final isGroupSplit = split.groupId != null;

          activities.add(
            ActivityItem(
              type:
                  isGroupSplit
                      ? ActivityType.groupSplit
                      : ActivityType.individualSplit,
              title: split.title,
              amount: split.totalAmount,
              date: split.createdAt,
              icon: isGroupSplit ? Icons.groups : Icons.person,
              color: isGroupSplit ? Colors.purple : const Color(0xFFFF7F50),
              subtitle:
                  split.paidBy == currentUserId ? 'You paid' : 'Split expense',
            ),
          );
        }

        // Sort by date (most recent first)
        activities.sort((a, b) => b.date.compareTo(a.date));
        final displayActivities = activities.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (displayActivities.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No recent activity',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start by adding an expense or splitting a bill',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayActivities.length,
                  separatorBuilder:
                      (context, index) =>
                          Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final activity = displayActivities[index];
                    return _buildActivityItem(activity);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: activity.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(activity.icon, color: activity.color, size: 24),
      ),
      title: Text(
        activity.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            activity.subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDate(activity.date),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${activity.amount.toInt()}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: activity.color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: activity.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getActivityTypeLabel(activity.type),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: activity.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getActivityTypeLabel(ActivityType type) {
    switch (type) {
      case ActivityType.personalExpense:
        return 'PERSONAL';
      case ActivityType.individualSplit:
        return 'SPLIT';
      case ActivityType.groupSplit:
        return 'GROUP';
    }
  }
}

enum ActivityType { personalExpense, individualSplit, groupSplit }

class ActivityItem {
  final ActivityType type;
  final String title;
  final double amount;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String subtitle;

  ActivityItem({
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}

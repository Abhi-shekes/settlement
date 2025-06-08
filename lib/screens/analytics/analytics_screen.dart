import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Month';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<ExpenseService>().loadUserExpenses(),
      context.read<GroupService>().loadUserSplits(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
                switch (value) {
                  case 'This Week':
                    _selectedDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
                    break;
                  case 'This Month':
                    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
                    break;
                  case 'This Year':
                    _selectedDate = DateTime(DateTime.now().year, 1, 1);
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Expenses'),
            Tab(text: 'Splits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildExpensesTab(),
          _buildSplitsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer2<ExpenseService, GroupService>(
      builder: (context, expenseService, groupService, child) {
        final currentUserId = context.read<AuthService>().currentUser?.uid ?? '';
        
        // Calculate totals
        final totalExpenses = expenseService.getTotalExpenseAmount();
        final totalOwed = groupService.getTotalAmountOwed(currentUserId);
        final totalOwing = groupService.getTotalAmountOwing(currentUserId);
        final netBalance = totalOwing - totalOwed;
        
        // Get category data
        final categoryData = expenseService.getCategoryWiseExpenses();
        final nonZeroCategories = categoryData.entries
            .where((entry) => entry.value > 0)
            .toList();

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF008080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Selector
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
                      Text(
                        _selectedPeriod,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedDate),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Expenses',
                        '₹${totalExpenses.toStringAsFixed(2)}',
                        Icons.receipt_long,
                        const Color(0xFF008080),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Net Balance',
                        netBalance >= 0 
                            ? '+₹${netBalance.toStringAsFixed(2)}'
                            : '-₹${(-netBalance).toStringAsFixed(2)}',
                        netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                        netBalance >= 0 ? Colors.green : const Color(0xFFFF7F50),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'You Owe',
                        '₹${totalOwed.toStringAsFixed(2)}',
                        Icons.arrow_upward,
                        const Color(0xFFFF7F50),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Owed to You',
                        '₹${totalOwing.toStringAsFixed(2)}',
                        Icons.arrow_downward,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Category Breakdown
                if (nonZeroCategories.isNotEmpty) ...[
                  const Text(
                    'Expense Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008080),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieChartSections(nonZeroCategories),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Category Legend
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: nonZeroCategories.map((entry) {
                      return _buildCategoryLegend(
                        entry.key,
                        entry.value,
                        _getCategoryColor(entry.key),
                      );
                    }).toList(),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Quick Stats
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickStats(expenseService, groupService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab() {
    return Consumer<ExpenseService>(
      builder: (context, expenseService, child) {
        final expenses = expenseService.expenses;
        
        // Get data for the selected period
        Map<String, double> chartData;
        switch (_selectedPeriod) {
          case 'This Week':
            chartData = expenseService.getWeeklyExpenses(_selectedDate);
            break;
          case 'This Month':
            chartData = expenseService.getMonthlyExpenses(_selectedDate);
            break;
          case 'This Year':
            chartData = _getYearlyExpenses(expenseService, _selectedDate);
            break;
          default:
            chartData = expenseService.getMonthlyExpenses(_selectedDate);
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF008080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expense Trend Chart
                const Text(
                  'Expense Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '₹${value.toInt()}',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = chartData.keys.toList();
                              if (value.toInt() < keys.length) {
                                return Text(
                                  keys[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _buildLineChartSpots(chartData),
                          isCurved: true,
                          color: const Color(0xFF008080),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF008080).withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Category Breakdown Bar Chart
                const Text(
                  'Category Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxCategoryValue(expenseService),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '₹${value.toInt()}',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final categories = ExpenseCategory.values;
                              if (value.toInt() < categories.length) {
                                return Text(
                                  categories[value.toInt()].toString().split('.').last.substring(0, 3).toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarChartGroups(expenseService),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Recent Expenses
                const Text(
                  'Recent Expenses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.take(5).length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _buildRecentExpenseCard(expense);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSplitsTab() {
    return Consumer2<GroupService, AuthService>(
      builder: (context, groupService, authService, child) {
        final currentUserId = authService.currentUser?.uid ?? '';
        final splits = groupService.splits;
        
        // Calculate split statistics
        final totalSplits = splits.length;
        final settledSplits = splits.where((s) => s.isFullySettled).length;
        final pendingSplits = totalSplits - settledSplits;
        
        final youOweSplits = groupService.getUserOwedSplits(currentUserId);
        final owedToYouSplits = groupService.getUserOwingSplits(currentUserId);

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF008080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Split Summary
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Splits',
                        totalSplits.toString(),
                        Icons.call_split,
                        const Color(0xFF008080),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Settled',
                        settledSplits.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Pending',
                        pendingSplits.toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Settlement Rate',
                        totalSplits > 0 ? '${((settledSplits / totalSplits) * 100).toStringAsFixed(1)}%' : '0%',
                        Icons.analytics,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Split Status Chart
                if (totalSplits > 0) ...[
                  const Text(
                    'Split Status Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008080),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: settledSplits.toDouble(),
                            title: 'Settled\n$settledSplits',
                            color: Colors.green,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: pendingSplits.toDouble(),
                            title: 'Pending\n$pendingSplits',
                            color: Colors.orange,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Recent Splits
                const Text(
                  'Recent Splits',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008080),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: splits.take(5).length,
                  itemBuilder: (context, index) {
                    final split = splits[index];
                    return _buildRecentSplitCard(split, currentUserId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<MapEntry<ExpenseCategory, double>> categories) {
    return categories.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${((entry.value / categories.fold(0.0, (sum, e) => sum + e.value)) * 100).toStringAsFixed(1)}%',
        color: _getCategoryColor(entry.key),
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryLegend(ExpenseCategory category, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ExpenseService expenseService, GroupService groupService) {
    final expenses = expenseService.expenses;
    final avgExpense = expenses.isNotEmpty ? expenseService.getTotalExpenseAmount() / expenses.length : 0.0;
    final highestExpense = expenses.isNotEmpty ? expenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b) : 0.0;
    final thisMonthExpenses = expenses.where((e) => 
        e.createdAt.month == DateTime.now().month && 
        e.createdAt.year == DateTime.now().year).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatRow('Average Expense', '₹${avgExpense.toStringAsFixed(2)}'),
          const Divider(),
          _buildStatRow('Highest Expense', '₹${highestExpense.toStringAsFixed(2)}'),
          const Divider(),
          _buildStatRow('This Month Expenses', thisMonthExpenses.toString()),
          const Divider(),
          _buildStatRow('Total Transactions', expenses.length.toString()),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF008080),
            ),
          ),
        ],
      ),
    );
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

  Map<String, double> _getYearlyExpenses(ExpenseService expenseService, DateTime year) {
    final Map<String, double> monthlyData = {};
    
    for (int i = 1; i <= 12; i++) {
      final month = DateTime(year.year, i, 1);
      final nextMonth = DateTime(year.year, i + 1, 1);
      
      final monthlyExpenses = expenseService.getExpensesByDateRange(month, nextMonth);
      monthlyData[DateFormat('MMM').format(month)] = 
          monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);
    }
    
    return monthlyData;
  }

  List<FlSpot> _buildLineChartSpots(Map<String, double> data) {
    final spots = <FlSpot>[];
    final keys = data.keys.toList();
    
    for (int i = 0; i < keys.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[keys[i]]!));
    }
    
    return spots;
  }

  double _getMaxCategoryValue(ExpenseService expenseService) {
    final categoryData = expenseService.getCategoryWiseExpenses();
    return categoryData.values.isNotEmpty 
        ? categoryData.values.reduce((a, b) => a > b ? a : b) * 1.2
        : 100;
  }

  List<BarChartGroupData> _buildBarChartGroups(ExpenseService expenseService) {
    final categoryData = expenseService.getCategoryWiseExpenses();
    final groups = <BarChartGroupData>[];
    
    for (int i = 0; i < ExpenseCategory.values.length; i++) {
      final category = ExpenseCategory.values[i];
      final value = categoryData[category] ?? 0.0;
      
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: _getCategoryColor(category),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }
    
    return groups;
  }

  Widget _buildRecentExpenseCard(ExpenseModel expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(expense.category).withOpacity(0.1),
          child: Icon(
            _getCategoryIcon(expense.category),
            color: _getCategoryColor(expense.category),
            size: 20,
          ),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(DateFormat('MMM d, y').format(expense.createdAt)),
        trailing: Text(
          expense.formattedAmount,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF008080),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSplitCard(split, String currentUserId) {
    final isPayer = split.paidBy == currentUserId;
    final isGroupSplit = split.groupId != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGroupSplit 
              ? Colors.purple.withOpacity(0.1) 
              : const Color(0xFFFF7F50).withOpacity(0.1),
          child: Icon(
            isGroupSplit ? Icons.groups : Icons.person,
            color: isGroupSplit ? Colors.purple : const Color(0xFFFF7F50),
            size: 20,
          ),
        ),
        title: Text(
          split.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${isPayer ? "You paid" : "Split"} • ${DateFormat('MMM d, y').format(split.createdAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              split.formattedTotalAmount,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isGroupSplit ? Colors.purple : const Color(0xFFFF7F50),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: split.isFullySettled 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                split.isFullySettled ? 'Settled' : 'Pending',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: split.isFullySettled ? Colors.green : Colors.orange,
                ),
              ),
            ),
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
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../services/expense_service.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/money.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Month';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
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
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range_rounded),
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
                switch (value) {
                  case 'This Week':
                    _selectedDate = DateTime.now().subtract(
                      Duration(days: DateTime.now().weekday - 1),
                    );
                    break;
                  case 'This Month':
                    _selectedDate = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      1,
                    );
                    break;
                  case 'This Year':
                    _selectedDate = DateTime(DateTime.now().year, 1, 1);
                    break;
                }
              });
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 'This Week', child: Text('This Week')),
                  PopupMenuItem(value: 'This Month', child: Text('This Month')),
                  PopupMenuItem(value: 'This Year', child: Text('This Year')),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Expenses'), Tab(text: 'Splits')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildExpensesTab(), _buildSplitsTab()],
      ),
    );
  }

  Widget _card({required double height, required Widget child}) {
    final c = context.colors;
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildExpensesTab() {
    return Consumer<ExpenseService>(
      builder: (context, expenseService, child) {
        final c = context.colors;
        Map<String, double> chartData;
        switch (_selectedPeriod) {
          case 'This Week':
            chartData = expenseService.getWeeklyExpenses(_selectedDate);
            break;
          case 'This Year':
            chartData = _getYearlyExpenses(expenseService, _selectedDate);
            break;
          case 'This Month':
          default:
            chartData = expenseService.getMonthlyExpenses(_selectedDate);
        }

        final total = chartData.values.fold(0.0, (a, b) => a + b);

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: c.brand,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: '$_selectedPeriod spend',
                        icon: Icons.trending_up_rounded,
                        accent: c.brand,
                        amount: total,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Categories used',
                        icon: Icons.donut_large_rounded,
                        accent: c.info,
                        valueText:
                            '${expenseService.getCategoryWiseExpenses().entries.where((e) => e.value > 0).length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Expense trend'),
                const SizedBox(height: AppSpacing.sm),
                _card(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine:
                            (_) => FlLine(color: c.cardBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget:
                                (value, meta) => Text(
                                  formatCurrency(value, compact: true),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: c.faint,
                                  ),
                                ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = chartData.keys.toList();
                              if (value.toInt() < keys.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    keys[value.toInt()],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: c.faint,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _buildLineChartSpots(chartData),
                          isCurved: true,
                          color: c.brand,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: c.brand.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Category breakdown'),
                const SizedBox(height: AppSpacing.sm),
                _card(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxCategoryValue(expenseService),
                      barTouchData: BarTouchData(enabled: true),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine:
                            (_) => FlLine(color: c.cardBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget:
                                (value, meta) => Text(
                                  formatCurrency(value, compact: true),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: c.faint,
                                  ),
                                ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final categories = CategoryRegistry.instance.all;
                              if (value.toInt() < categories.length) {
                                final name =
                                    categories[value.toInt()]
                                        .categoryDisplayName;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    name.length <= 3
                                        ? name
                                        : name.substring(0, 3),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: c.faint,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarChartGroups(expenseService),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
        final c = context.colors;
        final splits = groupService.splits;
        final totalSplits = splits.length;
        final settledSplits = splits.where((s) => s.isFullySettled).length;
        final pendingSplits = totalSplits - settledSplits;

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: c.brand,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Total splits',
                        icon: Icons.call_split_rounded,
                        accent: c.brand,
                        valueText: '$totalSplits',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Settled',
                        icon: Icons.check_circle_rounded,
                        accent: c.positive,
                        valueText: '$settledSplits',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Pending',
                        icon: Icons.hourglass_bottom_rounded,
                        accent: c.warning,
                        valueText: '$pendingSplits',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Settlement rate',
                        icon: Icons.percent_rounded,
                        accent: c.info,
                        valueText:
                            totalSplits > 0
                                ? '${((settledSplits / totalSplits) * 100).toInt()}%'
                                : '0%',
                      ),
                    ),
                  ],
                ),
                if (totalSplits > 0) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader('Split status'),
                  const SizedBox(height: AppSpacing.sm),
                  _card(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: settledSplits.toDouble(),
                            title: 'Settled\n$settledSplits',
                            color: c.positive,
                            radius: 62,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: pendingSplits.toDouble(),
                            title: 'Pending\n$pendingSplits',
                            color: c.warning,
                            radius: 62,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, double> _getYearlyExpenses(
    ExpenseService expenseService,
    DateTime year,
  ) {
    final Map<String, double> monthlyData = {};
    for (int i = 1; i <= 12; i++) {
      final month = DateTime(year.year, i, 1);
      final nextMonth = DateTime(year.year, i + 1, 1);
      final monthlyExpenses = expenseService.getExpensesByDateRange(
        month,
        nextMonth,
      );
      monthlyData[DateFormat('MMM').format(month)] = monthlyExpenses.fold(
        0.0,
        (sum, e) => sum + e.amount,
      );
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
    final categories = CategoryRegistry.instance.all;
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final value = categoryData[category] ?? 0.0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: category.color,
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    return groups;
  }
}

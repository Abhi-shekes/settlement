import 'package:flutter/material.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final ExpenseService _expenseService = ExpenseService();
  bool _isLoading = true;
  Map<String, double> _categorySummary = {};
  Map<String, double> _monthlySummary = {};
  String _selectedTimeFrame = 'This Month';
  final List<String> _timeFrames = [
    'This Month',
    'Last 3 Months',
    'Last 6 Months',
    'This Year',
  ];

  late TabController _tabController;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categorySummary =
          await _expenseService.getExpenseSummaryByCategory();
      final monthlySummary = await _expenseService.getMonthlyExpenseSummary();

      setState(() {
        _categorySummary = categorySummary;
        _monthlySummary = _filterMonthlySummary(
          monthlySummary,
          _selectedTimeFrame,
        );
      });
    } catch (e) {
      print('Error loading analytics data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, double> _filterMonthlySummary(
    Map<String, double> summary,
    String timeFrame,
  ) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    Map<String, double> filtered = {};

    switch (timeFrame) {
      case 'This Month':
        final key = '$currentMonth-$currentYear';
        if (summary.containsKey(key)) {
          filtered[key] = summary[key]!;
        }
        break;
      case 'Last 3 Months':
        for (int i = 0; i < 3; i++) {
          final month =
              currentMonth - i <= 0 ? currentMonth - i + 12 : currentMonth - i;
          final year = currentMonth - i <= 0 ? currentYear - 1 : currentYear;
          final key = '$month-$year';
          if (summary.containsKey(key)) {
            filtered[key] = summary[key]!;
          }
        }
        break;
      case 'Last 6 Months':
        for (int i = 0; i < 6; i++) {
          final month =
              currentMonth - i <= 0 ? currentMonth - i + 12 : currentMonth - i;
          final year = currentMonth - i <= 0 ? currentYear - 1 : currentYear;
          final key = '$month-$year';
          if (summary.containsKey(key)) {
            filtered[key] = summary[key]!;
          }
        }
        break;
      case 'This Year':
        for (int month = 1; month <= 12; month++) {
          final key = '$month-$currentYear';
          if (summary.containsKey(key)) {
            filtered[key] = summary[key]!;
          }
        }
        break;
    }

    return filtered;
  }

  String _formatMonthYear(String key) {
    final parts = key.split('-');
    if (parts.length == 2) {
      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]);
      return DateFormat('MMM yyyy').format(DateTime(year, month));
    }
    return key;
  }

  double _getTotalExpense() {
    return _categorySummary.values.fold(0.0, (sum, value) => sum + value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedTimeFrame = value;
                _loadData();
              });
            },
            itemBuilder: (context) {
              return _timeFrames.map((option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        option == _selectedTimeFrame
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color:
                            option == _selectedTimeFrame
                                ? Theme.of(context).primaryColor
                                : null,
                      ),
                      SizedBox(width: 8),
                      Text(option),
                    ],
                  ),
                );
              }).toList();
            },
            icon: Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'CATEGORIES'), Tab(text: 'MONTHLY')],
            ),
          ),

          // Summary card
          if (!_isLoading)
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₹${_getTotalExpense().toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _selectedTimeFrame,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fade().slideY(begin: -0.2, end: 0, duration: 400.ms),

          // Main content
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Loading analytics...',
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : TabBarView(
                      controller: _tabController,
                      children: [_buildCategoryTab(), _buildMonthlyTab()],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab() {
    return _categorySummary.isEmpty
        ? _buildEmptyState('No category data available')
        : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPieChart(),
              const SizedBox(height: 24),
              _buildCategoryList(),
            ],
          ),
        );
  }

  Widget _buildMonthlyTab() {
    return _monthlySummary.isEmpty
        ? _buildEmptyState('No monthly data available')
        : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBarChart(),
              const SizedBox(height: 24),
              _buildMonthlyList(),
            ],
          ),
        );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[400],
          ).animate().fade(duration: 600.ms).scale(),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
          ).animate().fade(delay: 300.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),

            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ).animate().fade(delay: 600.ms).moveY(begin: 20, end: 0),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final totalExpense = _getTotalExpense();
    final List<Color> colors = [
      const Color(0xFF5C6BC0), // Indigo
      const Color(0xFFEC407A), // Pink
      const Color(0xFF26A69A), // Teal
      const Color(0xFFFFCA28), // Amber
      const Color(0xFF42A5F5), // Blue
      const Color(0xFFEF5350), // Red
      const Color(0xFF66BB6A), // Green
      const Color(0xFF8D6E63), // Brown
      const Color(0xFF7E57C2), // Deep Purple
      const Color(0xFFFF7043), // Deep Orange
    ];

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Distribution',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap on segments for details',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex =
                            pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: List.generate(_categorySummary.entries.length, (
                    index,
                  ) {
                    final entry = _categorySummary.entries.elementAt(index);
                    final percentage = (entry.value / totalExpense) * 100;
                    final isTouched = index == _touchedIndex;
                    final fontSize = isTouched ? 18.0 : 14.0;
                    final radius = isTouched ? 90.0 : 80.0;

                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    );
                  }),
                ),
              ).animate().fade(duration: 800.ms).scale(delay: 300.ms),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.2, end: 0, duration: 600.ms);
  }

  Widget _buildCategoryList() {
    final List<Color> colors = [
      const Color(0xFF5C6BC0), // Indigo
      const Color(0xFFEC407A), // Pink
      const Color(0xFF26A69A), // Teal
      const Color(0xFFFFCA28), // Amber
      const Color(0xFF42A5F5), // Blue
      const Color(0xFFEF5350), // Red
      const Color(0xFF66BB6A), // Green
      const Color(0xFF8D6E63), // Brown
      const Color(0xFF7E57C2), // Deep Purple
      const Color(0xFFFF7043), // Deep Orange
    ];

    final totalExpense = _getTotalExpense();
    final sortedEntries =
        _categorySummary.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Breakdown',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(sortedEntries.length, (index) {
                  final entry = sortedEntries[index];
                  final percentage = (entry.value / totalExpense) * 100;

                  return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: colors[index % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${entry.value.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${percentage.toStringAsFixed(1)}%)',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors[index % colors.length],
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      )
                      .animate(delay: Duration(milliseconds: 100 * index))
                      .fade()
                      .slideX();
                }),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: 300.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms);
  }

  Widget _buildBarChart() {
    final sortedEntries =
        _monthlySummary.entries.toList()..sort((a, b) {
          final aDate = DateFormat('M-yyyy').parse(a.key);
          final bDate = DateFormat('M-yyyy').parse(b.key);
          return aDate.compareTo(bDate);
        });

    final maxY =
        sortedEntries.isEmpty
            ? 1000.0
            : sortedEntries
                    .map((e) => e.value)
                    .reduce((a, b) => a > b ? a : b) *
                1.2;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trend',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTimeFrame,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = sortedEntries[groupIndex];
                        return BarTooltipItem(
                          '${_formatMonthYear(entry.key)}\n₹${rod.toY.toInt()}',
                          GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('₹0');
                          if (value == maxY / 2) {
                            return Text('₹${(maxY / 2).toStringAsFixed(0)}');
                          }
                          if (value == maxY) {
                            return Text('₹${maxY.toStringAsFixed(0)}');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedEntries.length) {
                            final key = sortedEntries[index].key;
                            final parts = key.split('-');
                            final month = int.parse(parts[0]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM').format(DateTime(0, month)),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  barGroups: List.generate(sortedEntries.length, (index) {
                    final entry = sortedEntries[index];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          width: 22,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: Colors.grey[200],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ).animate().fade(duration: 800.ms).scale(delay: 300.ms),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.2, end: 0, duration: 600.ms);
  }

  Widget _buildMonthlyList() {
    final sortedEntries =
        _monthlySummary.entries.toList()..sort((a, b) {
          final aDate = DateFormat('M-yyyy').parse(a.key);
          final bDate = DateFormat('M-yyyy').parse(b.key);
          return bDate.compareTo(aDate); // Reverse order - most recent first
        });

    return Card(
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(sortedEntries.length, (index) {
                  final entry = sortedEntries[index];
                  final formattedDate = _formatMonthYear(entry.key);

                  return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Total expenses for this month',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${entry.value.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate(delay: Duration(milliseconds: 100 * index))
                      .fade()
                      .slideX();
                }),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: 300.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms);
  }
}

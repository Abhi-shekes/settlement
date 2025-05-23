import 'package:expense_tracker/screens/expenses/expenses_screen.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/expenses/add_expense_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ExpenseService _expenseService = ExpenseService();
  bool _isLoading = true;
  double _totalExpenses = 0;
  Map<String, double> _categorySummary = {};
  List<Expense> _recentExpenses = [];
  double _owedToMe = 0;
  double _iOwe = 0;
  Map<String, double> _individualBalances = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categorySummary =
          await _expenseService.getExpenseSummaryByCategory();
      _categorySummary = categorySummary;
      _totalExpenses = categorySummary.values.fold(
        0,
        (sum, amount) => sum + amount,
      );

      _expenseService.getAllUserExpenses().listen((expenses) {
        if (mounted) {
          setState(() {
            _recentExpenses = expenses.take(5).toList();
          });
        }
      });

      // Get updated owed amounts with settlement calculations
      final owedData = await _expenseService.getOwedAmounts();
      _owedToMe = owedData['owedToMe'] ?? 0;
      _iOwe = owedData['iOwe'] ?? 0;
      _individualBalances = Map<String, double>.from(
        owedData["individualBalances"] ?? {},
      );
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Horizontally scrollable row for the 3 containers
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Total Expenses container with fixed width
                            Container(
                              width: 150, // Set a fixed width
                              child: Card(
                                elevation: 2,
                                color: Theme.of(context).primaryColor,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Month',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '₹${_totalExpenses.toInt()}',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),

                            // Amount Owed to Me container with fixed width
                            Container(
                              width: 150, // Set a fixed width
                              child: Card(
                                elevation: 2,
                                color: Colors.teal,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(10, 16, 16, 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.trending_up,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Owed To Me',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '₹${_owedToMe.toInt()}',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),

                            // Amount I Owe container with fixed width
                            Container(
                              width: 150, // Set a fixed width
                              child: Card(
                                elevation: 2,
                                color: Colors.teal,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.trending_down,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'I Owe',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '₹${_iOwe.toInt()}',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Category summary
                      Text(
                        'Expense Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      _categorySummary.isEmpty
                          ? Card(
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No expenses recorded yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ),
                          )
                          : Card(
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children:
                                    _categorySummary.entries.map((entry) {
                                      final percentage =
                                          _totalExpenses > 0
                                              ? (entry.value / _totalExpenses) *
                                                  100
                                              : 0;
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(entry.key),
                                                Text(
                                                  '₹${entry.value.toInt()} (${percentage.toStringAsFixed(1)}%)',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            LinearProgressIndicator(
                                              value:
                                                  _totalExpenses > 0
                                                      ? entry.value /
                                                          _totalExpenses
                                                      : 0,
                                              backgroundColor: Colors.grey[200],
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                      SizedBox(height: 24),

                      // Recent transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to all expenses
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExpensesScreen(),
                                ),
                              );
                            },
                            child: Text('See All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _recentExpenses.isEmpty
                          ? Card(
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No recent transactions',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ),
                          )
                          : Column(
                            children:
                                _recentExpenses.map((expense) {
                                  return Card(
                                    elevation: 1,
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.2),
                                        child: Icon(
                                          Icons.receipt,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      title: Text(expense.title),
                                      subtitle: Text(
                                        DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(expense.date),
                                      ),
                                      trailing: Text(
                                        '₹${expense.amount.toInt()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen()),
          ).then((_) => _loadData());
        },
        child: Icon(Icons.add),
        tooltip: 'Add Expense',
      ),
    );
  }
}

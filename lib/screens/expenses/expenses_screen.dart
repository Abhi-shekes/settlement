import 'package:flutter/material.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/expenses/add_expense_screen.dart';
import 'package:expense_tracker/screens/expenses/expense_detail_screen.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  @override
  _ExpensesScreenState createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Today',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    _expenseService.getExpenses().listen((expenses) {
      if (mounted) {
        setState(() {
          _expenses = _filterExpenses(expenses, _selectedFilter);
          _isLoading = false;
        });
      }
    });
  }

  List<Expense> _filterExpenses(List<Expense> expenses, String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    switch (filter) {
      case 'Today':
        return expenses.where((expense) {
          final expenseDate = DateTime(
            expense.date.year,
            expense.date.month,
            expense.date.day,
          );
          return expenseDate.isAtSameMomentAs(today);
        }).toList();
      case 'This Week':
        return expenses.where((expense) {
          final expenseDate = DateTime(
            expense.date.year,
            expense.date.month,
            expense.date.day,
          );
          return expenseDate.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              expenseDate.isBefore(startOfWeek.add(Duration(days: 7)));
        }).toList();
      case 'This Month':
        return expenses.where((expense) {
          final expenseDate = DateTime(
            expense.date.year,
            expense.date.month,
            expense.date.day,
          );
          return expenseDate.isAfter(
                startOfMonth.subtract(Duration(days: 1)),
              ) &&
              expenseDate.isBefore(DateTime(now.year, now.month + 1, 0));
        }).toList();
      default:
        return expenses;
    }
  }

  void _deleteExpense(String expenseId) async {
    try {
      await _expenseService.deleteExpense(expenseId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Expense deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                _expenses = _filterExpenses(_expenses, value);
              });
            },
            itemBuilder: (context) {
              return _filterOptions.map((option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        option == _selectedFilter
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color:
                            option == _selectedFilter
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
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _expenses.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No expenses found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _selectedFilter != 'All'
                          ? 'Try changing the filter or add a new expense'
                          : 'Add your first expense to get started',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddExpenseScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add Expense'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
                  return Dismissible(
                    key: Key(expense.id),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text('Delete Expense'),
                              content: Text(
                                'Are you sure you want to delete this expense?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                    onDismissed: (direction) {
                      _deleteExpense(expense.id);
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          '${expense.category} • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
                        ),
                        trailing: Text(
                          '\₹${expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      ExpenseDetailScreen(expense: expense),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Expense',
      ),
    );
  }
}

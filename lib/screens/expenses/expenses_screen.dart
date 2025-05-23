import 'package:flutter/material.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/services/settlement_service.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/friend_service.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:expense_tracker/screens/expenses/add_expense_screen.dart';
import 'package:expense_tracker/screens/expenses/expense_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpensesScreen extends StatefulWidget {
  @override
  _ExpensesScreenState createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final SettlementService _settlementService = SettlementService();
  final AuthService _authService = AuthService();
  final FriendService _friendService = FriendService();

  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _currentUserId = '';
  Map<String, UserProfile> _userProfiles = {};
  Map<String, bool> _settlementStatus = {};

  final List<String> _filterOptions = [
    'All',
    'Today',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _loadExpenses();
  }

  void _loadExpenses() {
    _expenseService.getAllUserExpenses().listen((expenses) async {
      if (mounted) {
        // Load user profiles and settlement status
        await _loadUserProfiles(expenses);
        await _loadSettlementStatus(expenses);

        setState(() {
          _expenses = _filterExpenses(expenses, _selectedFilter);
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadUserProfiles(List<Expense> expenses) async {
    Set<String> userIds = {};

    for (Expense expense in expenses) {
      if (expense.splitDetails != null) {
        userIds.addAll(expense.splitDetails!.keys);
      }
      userIds.add(expense.userId);
    }

    for (String userId in userIds) {
      if (!_userProfiles.containsKey(userId)) {
        final profile = await _authService.getUserProfile(userId);
        if (profile != null) {
          _userProfiles[userId] = profile;
        }
      }
    }
  }

  Future<void> _loadSettlementStatus(List<Expense> expenses) async {
    for (Expense expense in expenses) {
      if (expense.groupId == null &&
          expense.splitDetails != null &&
          expense.splitDetails!.length == 2) {
        bool isSettled = await _expenseService.isIndividualExpenseSettled(
          expense.id,
        );
        _settlementStatus[expense.id] = isSettled;
      }
    }
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

  // Determine expense type and return appropriate icon and color
  Map<String, dynamic> _getExpenseTypeInfo(Expense expense) {
    if (expense.groupId != null) {
      // Group split expense
      return {
        'icon': Icons.group,
        'color': Colors.purple,
        'type': 'Group Split',
        'backgroundColor': Colors.purple.withOpacity(0.1),
      };
    } else if (expense.splitDetails != null &&
        expense.splitDetails!.length == 2) {
      // Individual split expense
      return {
        'icon': Icons.people,
        'color': Colors.blue,
        'type': 'Split with Friend',
        'backgroundColor': Colors.blue.withOpacity(0.1),
      };
    } else {
      // Personal expense
      return {
        'icon': Icons.person,
        'color': Theme.of(context).primaryColor,
        'type': 'Personal',
        'backgroundColor': Theme.of(context).primaryColor.withOpacity(0.1),
      };
    }
  }

  // Get friend name for individual split
  String _getFriendName(Expense expense) {
    if (expense.splitDetails != null) {
      for (String userId in expense.splitDetails!.keys) {
        if (userId != _currentUserId) {
          return _userProfiles[userId]?.name ?? 'Friend';
        }
      }
    }
    return 'Friend';
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

  void _showSettleDialog(Expense expense) {
    final friendName = _getFriendName(expense);
    final yourAmount = expense.splitDetails![_currentUserId] ?? 0;

    // Find friend's amount and ID
    String? friendId;
    double friendAmount = 0;
    for (var entry in expense.splitDetails!.entries) {
      if (entry.key != _currentUserId) {
        friendId = entry.key;
        friendAmount = entry.value;
        break;
      }
    }

    if (friendId == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Settle Split Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense: ${expense.title}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Total Amount: ₹${expense.amount.toInt()}'),
                SizedBox(height: 16),
                Text(
                  'Split Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('You:'), Text('₹${yourAmount.toInt()}')],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$friendName:'),
                    Text('₹${friendAmount.toInt()}'),
                  ],
                ),
                SizedBox(height: 16),
                if (expense.userId == _currentUserId) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You paid this expense. $friendName owes you ₹${friendAmount.toInt()}',
                            style: TextStyle(color: Colors.green[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$friendName paid this expense. You owe ₹${yourAmount.toInt()}',
                            style: TextStyle(color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markAsSettled(expense, friendId!, friendAmount, yourAmount);
                },
                child: Text('Mark as Settled'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  void _markAsSettled(
    Expense expense,
    String friendId,
    double friendAmount,
    double yourAmount,
  ) async {
    try {
      // Determine who owes whom and how much
      String fromUserId;
      String toUserId;
      double settlementAmount;

      if (expense.userId == _currentUserId) {
        // You paid, friend owes you
        fromUserId = friendId;
        toUserId = _currentUserId;
        settlementAmount = friendAmount;
      } else {
        // Friend paid, you owe friend
        fromUserId = _currentUserId;
        toUserId = friendId;
        settlementAmount = yourAmount;
      }

      await _settlementService.recordSettlement(
        expenseId: expense.id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: settlementAmount,
        isPartial: false,
        note: 'Full settlement',
      );

      // Update local settlement status
      setState(() {
        _settlementStatus[expense.id] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense marked as settled'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error settling expense: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  final expenseInfo = _getExpenseTypeInfo(expense);
                  final isIndividualSplit =
                      expense.groupId == null &&
                      expense.splitDetails != null &&
                      expense.splitDetails!.length == 2;
                  final isSettled = _settlementStatus[expense.id] ?? false;

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
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: expenseInfo['backgroundColor'],
                              child: Icon(
                                expenseInfo['icon'],
                                color: expenseInfo['color'],
                                size: 24,
                              ),
                            ),
                            if (isIndividualSplit && !isSettled)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: expenseInfo['backgroundColor'],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                expenseInfo['type'],
                                style: TextStyle(
                                  color: expenseInfo['color'],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            Text(
                              '${expense.category} • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (isIndividualSplit) ...[
                              SizedBox(height: 4),
                              Text(
                                'Split with ${_getFriendName(expense)}',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${expense.amount.toInt()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (isIndividualSplit) ...[
                              SizedBox(height: 4),
                              GestureDetector(
                                onTap:
                                    isSettled
                                        ? null
                                        : () => _showSettleDialog(expense),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSettled
                                            ? Colors.green
                                            : Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isSettled ? 'Settled' : 'Settle',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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

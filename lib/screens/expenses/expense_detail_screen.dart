import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/models/group.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:expense_tracker/screens/expenses/add_expense_screen.dart';
import 'package:intl/intl.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;

  ExpenseDetailScreen({required this.expense});

  @override
  _ExpenseDetailScreenState createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();

  bool _isLoading = true;
  Group? _group;
  Map<String, UserProfile> _userProfiles = {};

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
      if (widget.expense.groupId != null) {
        _group = await _groupService.getGroup(widget.expense.groupId!);

        if (widget.expense.splitDetails != null) {
          for (String userId in widget.expense.splitDetails!.keys) {
            final userProfile = await _authService.getUserProfile(userId);
            if (userProfile != null) {
              _userProfiles[userId] = userProfile;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading expense details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteExpense() async {
    try {
      await _expenseService.deleteExpense(widget.expense.id);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting expense: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AddExpenseScreen(expense: widget.expense),
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text('Delete Expense'),
                      content: Text(
                        'Are you sure you want to delete this expense?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteExpense();
                          },
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expense header
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.expense.title,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '\₹${widget.expense.amount.toInt()}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'MMMM dd, yyyy',
                                  ).format(widget.expense.date),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 8),
                                Text(
                                  widget.expense.category,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Group details if it's a split expense
                    if (_group != null) ...[
                      Text(
                        'Split with Group',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.group,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _group!.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Split Details',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              if (widget.expense.splitDetails != null)
                                ...widget.expense.splitDetails!.entries.map((
                                  entry,
                                ) {
                                  final userId = entry.key;
                                  final amount = entry.value;
                                  final user = _userProfiles[userId];

                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.2),
                                          child: Text(
                                            user?.name
                                                    .substring(0, 1)
                                                    .toUpperCase() ??
                                                'U',
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            user?.name ?? 'Unknown User',
                                          ),
                                        ),
                                        Text(
                                          '\₹${amount.toInt()}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}

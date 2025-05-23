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
  bool _isIndividualSplit = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser!.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if this is a group split or individual split
      if (widget.expense.groupId != null) {
        // Group split
        _group = await _groupService.getGroup(widget.expense.groupId!);
      } else if (widget.expense.splitDetails != null &&
          widget.expense.splitDetails!.length == 2) {
        // Individual split (no group ID but has split details with 2 people)
        setState(() {
          _isIndividualSplit = true;
        });
      }

      // Load user profiles for all people involved in the split
      if (widget.expense.splitDetails != null) {
        for (String userId in widget.expense.splitDetails!.keys) {
          final userProfile = await _authService.getUserProfile(userId);
          if (userProfile != null) {
            _userProfiles[userId] = userProfile;
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

  // Get the appropriate icon for the expense type
  Widget _getExpenseTypeIcon() {
    if (_group != null) {
      // Group split expense
      return Icon(Icons.group, color: Colors.purple, size: 24);
    } else if (_isIndividualSplit) {
      // Individual split expense
      return Icon(Icons.people, color: Colors.blue, size: 24);
    } else {
      // Personal expense (no split)
      return Icon(
        Icons.person,
        color: Theme.of(context).primaryColor,
        size: 24,
      );
    }
  }

  // Get the expense type label
  String _getExpenseTypeLabel() {
    if (_group != null) {
      return 'Group Split Expense';
    } else if (_isIndividualSplit) {
      return 'Split with Friend';
    } else {
      return 'Personal Expense';
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Expense type indicator
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_group != null)
                                        ? Colors.purple.withOpacity(0.1)
                                        : _isIndividualSplit
                                        ? Colors.blue.withOpacity(0.1)
                                        : Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      (_group != null)
                                          ? Colors.purple.withOpacity(0.3)
                                          : _isIndividualSplit
                                          ? Colors.blue.withOpacity(0.3)
                                          : Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _getExpenseTypeIcon(),
                                  SizedBox(width: 8),
                                  Text(
                                    _getExpenseTypeLabel(),
                                    style: TextStyle(
                                      color:
                                          (_group != null)
                                              ? Colors.purple
                                              : _isIndividualSplit
                                              ? Colors.blue
                                              : Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
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
                                    '₹${widget.expense.amount.toInt()}',
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
                            if (widget.expense.userId == _currentUserId) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    size: 16,
                                    color: Colors.green[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'You paid this expense',
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (_userProfiles.containsKey(
                              widget.expense.userId,
                            )) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    size: 16,
                                    color: Colors.orange[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${_userProfiles[widget.expense.userId]!.name} paid this expense',
                                    style: TextStyle(
                                      color: Colors.orange[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Group split details
                    if (_group != null &&
                        widget.expense.splitDetails != null) ...[
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.group, color: Colors.purple),
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
                              ...widget.expense.splitDetails!.entries.map((
                                entry,
                              ) {
                                final userId = entry.key;
                                final amount = entry.value;
                                final user = _userProfiles[userId];
                                final isCurrentUser = userId == _currentUserId;

                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            isCurrentUser
                                                ? Colors.purple.withOpacity(0.2)
                                                : Colors.grey[300],
                                        child: Text(
                                          isCurrentUser
                                              ? 'You'.substring(0, 1)
                                              : user?.name
                                                      .substring(0, 1)
                                                      .toUpperCase() ??
                                                  'U',
                                          style: TextStyle(
                                            color:
                                                isCurrentUser
                                                    ? Colors.purple
                                                    : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isCurrentUser
                                              ? 'You'
                                              : user?.name ?? 'Unknown User',
                                          style: TextStyle(
                                            fontWeight:
                                                isCurrentUser
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₹${amount.toInt()}',
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

                    // Individual split details
                    if (_isIndividualSplit &&
                        widget.expense.splitDetails != null) ...[
                      Text(
                        'Split with Friend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Individual Split',
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
                              ...widget.expense.splitDetails!.entries.map((
                                entry,
                              ) {
                                final userId = entry.key;
                                final amount = entry.value;
                                final user = _userProfiles[userId];
                                final isCurrentUser = userId == _currentUserId;

                                // Find the friend (non-current user)
                                String? friendId;
                                for (String id
                                    in widget.expense.splitDetails!.keys) {
                                  if (id != _currentUserId) {
                                    friendId = id;
                                    break;
                                  }
                                }

                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            isCurrentUser
                                                ? Colors.blue.withOpacity(0.2)
                                                : Colors.grey[300],
                                        child: Text(
                                          isCurrentUser
                                              ? 'You'.substring(0, 1)
                                              : user?.name
                                                      .substring(0, 1)
                                                      .toUpperCase() ??
                                                  'U',
                                          style: TextStyle(
                                            color:
                                                isCurrentUser
                                                    ? Colors.blue
                                                    : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isCurrentUser
                                              ? 'You'
                                              : user?.name ?? 'Unknown User',
                                          style: TextStyle(
                                            fontWeight:
                                                isCurrentUser
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₹${amount.toInt()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),

                              // Show split ratio
                              if (widget.expense.splitDetails!.length == 2) ...[
                                SizedBox(height: 16),
                                Divider(),
                                SizedBox(height: 8),
                                _buildSplitRatioIndicator(
                                  widget.expense.splitDetails!,
                                ),
                              ],
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

  // Build a visual indicator of the split ratio
  Widget _buildSplitRatioIndicator(Map<String, double> splitDetails) {
    // Find your amount and friend's amount
    double yourAmount = 0;
    double friendAmount = 0;
    String friendName = 'Friend';

    for (var entry in splitDetails.entries) {
      if (entry.key == _currentUserId) {
        yourAmount = entry.value;
      } else {
        friendAmount = entry.value;
        friendName = _userProfiles[entry.key]?.name ?? 'Friend';
      }
    }

    // Calculate percentages
    double totalAmount = yourAmount + friendAmount;
    double yourPercentage = (yourAmount / totalAmount) * 100;
    double friendPercentage = (friendAmount / totalAmount) * 100;

    // Check if it's an equal split
    bool isEqualSplit = (yourPercentage - 50).abs() < 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEqualSplit ? 'Equal Split (50/50)' : 'Custom Split Ratio',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEqualSplit ? Colors.green : Colors.blue,
          ),
        ),
        SizedBox(height: 8),
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                flex: yourPercentage.round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      topRight:
                          yourPercentage >= 99
                              ? Radius.circular(12)
                              : Radius.zero,
                      bottomRight:
                          yourPercentage >= 99
                              ? Radius.circular(12)
                              : Radius.zero,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: friendPercentage.round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                      topLeft:
                          friendPercentage >= 99
                              ? Radius.circular(12)
                              : Radius.zero,
                      bottomLeft:
                          friendPercentage >= 99
                              ? Radius.circular(12)
                              : Radius.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'You: ${yourPercentage.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            Text(
              '$friendName: ${friendPercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

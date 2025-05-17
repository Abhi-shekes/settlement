import 'package:flutter/material.dart';
import 'package:expense_tracker/models/group.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/friend_service.dart';
import 'package:expense_tracker/screens/expenses/add_expense_screen.dart';
import 'package:expense_tracker/screens/expenses/expense_detail_screen.dart';
import 'package:intl/intl.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  GroupDetailScreen({required this.group});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService();
  final ExpenseService _expenseService = ExpenseService();
  final AuthService _authService = AuthService();
  final FriendService _friendService = FriendService();

  bool _isLoading = true;
  List<Expense> _groupExpenses = [];
  Map<String, UserProfile> _memberProfiles = {};
  Map<String, double> _balances = {};
  String _currentUserId = '';
  List<String> _settledPayments = [];

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
      for (String memberId in widget.group.members) {
        final profile = await _authService.getUserProfile(memberId);
        if (profile != null) {
          _memberProfiles[memberId] = profile;
        }
      }

      _expenseService.getGroupExpenses(widget.group.id).listen((expenses) {
        if (mounted) {
          setState(() {
            _groupExpenses = expenses;
            _calculateBalances(expenses);
            _isLoading = false;
          });
        }
      });

      // Load settled payments
      final settledPayments = await _groupService.getSettledPayments(
        widget.group.id,
      );
      if (mounted) {
        setState(() {
          _settledPayments = settledPayments;
        });
      }
    } catch (e) {
      print('Error loading group data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateBalances(List<Expense> expenses) {
    Map<String, double> paid = {};
    Map<String, double> owes = {};

    // Initialize maps
    for (String memberId in widget.group.members) {
      paid[memberId] = 0;
      owes[memberId] = 0;
    }

    // Calculate from expenses
    for (Expense expense in expenses) {
      paid[expense.userId] = (paid[expense.userId] ?? 0) + expense.amount;

      if (expense.splitDetails != null) {
        expense.splitDetails!.forEach((userId, amount) {
          owes[userId] = (owes[userId] ?? 0) + amount;
        });
      }
    }

    // Adjust for settled payments
    for (String paymentInfo in _settledPayments) {
      final parts = paymentInfo.split('|');
      if (parts.length == 3) {
        final fromId = parts[0];
        final toId = parts[1];
        final amount = double.parse(parts[2]);

        // When someone pays, it's like they paid an expense for the other person
        paid[fromId] = (paid[fromId] ?? 0) + amount;
        owes[toId] = (owes[toId] ?? 0) + amount;
      }
    }

    // Calculate final balances
    Map<String, double> balances = {};
    for (String memberId in widget.group.members) {
      balances[memberId] = (paid[memberId] ?? 0) - (owes[memberId] ?? 0);
    }

    setState(() {
      _balances = balances;
    });
  }

  Future<void> _addMember() async {
    final friends = await _friendService.getFriends();
    final nonMembers =
        friends
            .where((friend) => !widget.group.members.contains(friend.id))
            .toList();

    if (nonMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All your friends are already in this group')),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Member'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: nonMembers.length,
                itemBuilder: (context, index) {
                  final friend = nonMembers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(friend.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(friend.name),
                    subtitle: Text(friend.email),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await _groupService.addMemberToGroup(
                          widget.group.id,
                          friend.id,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${friend.name} added to group'),
                          ),
                        );
                        _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding member: $e')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Leave Group'),
            content: Text('Are you sure you want to leave this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _groupService.removeMemberFromGroup(
          widget.group.id,
          _currentUserId,
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error leaving group: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          PopupMenuButton(
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'add_member',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Add Member'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Leave Group',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
            onSelected: (value) {
              if (value == 'add_member') {
                _addMember();
              } else if (value == 'leave') {
                _leaveGroup();
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).primaryColor,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(
                            icon: Icon(Icons.receipt_long, size: 20),
                            text: 'Expenses',
                          ),
                          Tab(
                            icon: Icon(Icons.account_balance_wallet, size: 20),
                            text: 'Balances',
                          ),
                          Tab(
                            icon: Icon(Icons.people, size: 20),
                            text: 'Members',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Expenses Tab
                          _buildExpensesTab(),

                          // Balances Tab
                          _buildBalancesTab(),

                          // Members Tab
                          _buildMembersTab(),
                        ],
                      ),
                    ),
                  ],
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
        elevation: 4,
      ),
    );
  }

  Widget _buildExpensesTab() {
    return _groupExpenses.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No expenses yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Add an expense to get started',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        : ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _groupExpenses.length,
          itemBuilder: (context, index) {
            final expense = _groupExpenses[index];
            final creator = _memberProfiles[expense.userId];

            return Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ExpenseDetailScreen(expense: expense),
                      ),
                    ).then((_) => _loadData());
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              creator?.name.substring(0, 1).toUpperCase() ??
                                  'U',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
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
                              Text(
                                '${creator?.name ?? 'Unknown'} • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₹${expense.amount.toInt()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }

  Widget _buildBalancesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 20),
                  ..._balances.entries.map((entry) {
                    final userId = entry.key;
                    final balance = entry.value;
                    final user = _memberProfiles[userId];
                    final isCurrentUser = userId == _currentUserId;

                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isCurrentUser
                                ? Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  isCurrentUser
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                style: TextStyle(
                                  color:
                                      isCurrentUser
                                          ? Colors.white
                                          : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              isCurrentUser ? 'You' : (user?.name ?? 'Unknown'),
                              style: TextStyle(
                                fontWeight:
                                    isCurrentUser
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  balance > 0
                                      ? Colors.green.withOpacity(0.2)
                                      : balance < 0
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              balance > 0
                                  ? 'gets back ₹${balance.abs().toInt()}'
                                  : balance < 0
                                  ? 'owes ₹${balance.abs().toInt()}'
                                  : 'settled up',
                              style: TextStyle(
                                color:
                                    balance > 0
                                        ? Colors.green[700]
                                        : balance < 0
                                        ? Colors.red[700]
                                        : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
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
          SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Detailed Breakdown',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showSettleUpDialog();
                },
                icon: Icon(Icons.check_circle_outline, size: 18),
                label: Text('Settle Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    _calculatePayments().isEmpty
                        ? [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 48,
                                    color: Colors.green,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'All settled up!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Everyone is square with each other',
                                    style: TextStyle(color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]
                        : _calculatePayments().map((payment) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_forward,
                                  color: Theme.of(context).primaryColor,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    payment,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
              ),
            ),
          ),
          if (_settledPayments.isNotEmpty) ...[
            SizedBox(height: 24),
            Text(
              'Settlement History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      _settledPayments.map((paymentInfo) {
                        final parts = paymentInfo.split('|');
                        if (parts.length == 3) {
                          final fromId = parts[0];
                          final toId = parts[1];
                          // Don't extract the amount - we want to hide it

                          final fromUser = _memberProfiles[fromId];
                          final toUser = _memberProfiles[toId];

                          final fromName =
                              fromId == _currentUserId
                                  ? 'You'
                                  : (fromUser?.name ?? 'Unknown');
                          final toName =
                              toId == _currentUserId
                                  ? 'You'
                                  : (toUser?.name ?? 'Unknown');

                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '$fromName paid $toName', // Removed amount display
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSettleUpDialog() {
    final payments = _calculatePayments();
    if (payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Everyone is already settled up!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Settle Up'),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a payment to mark as settled:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: Icon(
                            Icons.payment,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(payments[index]),
                          onTap: () {
                            Navigator.pop(context);
                            _confirmSettlement(payments[index]);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _confirmSettlement(String payment) {
    // Extract the names and amount from the payment string
    // Format: "Name1 pays Name2 ₹amount"
    final regex = RegExp(r'(.*) pays (.*) ₹(\d+)');
    final match = regex.firstMatch(payment);

    if (match != null && match.groupCount >= 3) {
      final fromName = match.group(1)!;
      final toName = match.group(2)!;
      final amount = int.parse(match.group(3)!);

      // Find the user IDs from the names
      String? fromId;
      String? toId;

      if (fromName == 'You') {
        fromId = _currentUserId;
      } else {
        _memberProfiles.forEach((id, profile) {
          if (profile.name == fromName) {
            fromId = id;
          }
        });
      }

      if (toName == 'You') {
        toId = _currentUserId;
      } else {
        _memberProfiles.forEach((id, profile) {
          if (profile.name == toName) {
            toId = id;
          }
        });
      }

      if (fromId != null && toId != null) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Confirm Settlement'),
                content: Text(
                  'Are you sure $fromName has paid $toName ₹$amount?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await _groupService.recordSettlement(
                          widget.group.id,
                          fromId!,
                          toId!,
                          amount.toDouble(),
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment marked as settled'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error recording settlement: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
        );
      }
    }
  }

  List<String> _calculatePayments() {
    List<String> payments = [];
    List<MapEntry<String, double>> sortedBalances = _balances.entries.toList();

    // Filter out balances that are effectively zero (due to floating point precision)
    sortedBalances =
        sortedBalances.where((entry) => entry.value.abs() > 0.01).toList();

    // Sort by balance (lowest to highest)
    sortedBalances.sort((a, b) => a.value.compareTo(b.value));

    int i = 0;
    int j = sortedBalances.length - 1;

    while (i < j) {
      String debtor = sortedBalances[i].key;
      String creditor = sortedBalances[j].key;
      double debtorBalance = sortedBalances[i].value;
      double creditorBalance = sortedBalances[j].value;

      // If debtor doesn't owe anything or creditor isn't owed anything, break
      if (debtorBalance >= -0.01) break;
      if (creditorBalance <= 0.01) break;

      // Calculate the amount to be paid (minimum of what debtor owes and what creditor is owed)
      double amount = min(-debtorBalance, creditorBalance);

      // Round to avoid floating point issues
      amount = double.parse(amount.toStringAsFixed(2));

      // Skip very small amounts
      if (amount < 0.01) {
        if (debtorBalance >= -0.01) i++;
        if (creditorBalance <= 0.01) j--;
        continue;
      }

      String debtorName =
          debtor == _currentUserId
              ? 'You'
              : _memberProfiles[debtor]?.name ?? 'Unknown';
      String creditorName =
          creditor == _currentUserId
              ? 'You'
              : _memberProfiles[creditor]?.name ?? 'Unknown';

      payments.add('$debtorName pays $creditorName ₹${amount.toInt()}');

      // Update balances
      sortedBalances[i] = MapEntry(debtor, debtorBalance + amount);
      sortedBalances[j] = MapEntry(creditor, creditorBalance - amount);

      // Move to next debtor/creditor if their balance is effectively zero
      if (sortedBalances[i].value >= -0.01) i++;
      if (sortedBalances[j].value <= 0.01) j--;
    }

    return payments;
  }

  double min(double a, double b) {
    return a < b ? a : b;
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: widget.group.members.length,
      itemBuilder: (context, index) {
        final memberId = widget.group.members[index];
        final member = _memberProfiles[memberId];
        final isCreator = memberId == widget.group.createdBy;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          memberId == _currentUserId
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        member?.name.substring(0, 1).toUpperCase() ?? 'U',
                        style: TextStyle(
                          color:
                              memberId == _currentUserId
                                  ? Colors.white
                                  : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memberId == _currentUserId
                              ? 'You'
                              : (member?.name ?? 'Unknown'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          member?.email ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCreator)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Admin',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/services/friend_service.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/group.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;

  AddExpenseScreen({this.expense});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final ExpenseService _expenseService = ExpenseService();
  final GroupService _groupService = GroupService();
  final FriendService _friendService = FriendService();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  bool _isLoading = false;
  bool _isSplitBill = false;
  Group? _selectedGroup;
  List<Group> _userGroups = [];
  List<UserProfile> _groupMembers = [];
  Map<String, double> _splitAmounts = {};

  final List<String> _categories = [
    'Food',
    'Transportation',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Housing',
    'Health',
    'Travel',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadGroups();

    // If editing an existing expense
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _selectedDate = widget.expense!.date;
      _selectedCategory = widget.expense!.category;

      if (widget.expense!.groupId != null) {
        _isSplitBill = true;
        _loadGroupDetails(widget.expense!.groupId!);
        _splitAmounts = widget.expense!.splitDetails ?? {};
      }
    }
  }

  Future<void> _loadGroups() async {
    try {
      _groupService.getUserGroups().listen((groups) {
        if (mounted) {
          setState(() {
            _userGroups = groups;
          });
        }
      });
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  Future<void> _loadGroupDetails(String groupId) async {
    try {
      final group = await _groupService.getGroup(groupId);
      if (group != null && mounted) {
        setState(() {
          _selectedGroup = group;
        });

        List<UserProfile> members = [];
        for (String memberId in group.members) {
          final member = await _friendService.getUserProfile(memberId);
          if (member != null) {
            members.add(member);
          }
        }

        if (mounted) {
          setState(() {
            _groupMembers = members;
          });
        }
      }
    } catch (e) {
      print('Error loading group details: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _updateSplitAmounts() {
    if (_selectedGroup != null && _amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final memberCount = _selectedGroup!.members.length;
      final splitAmount = amount / memberCount;

      Map<String, double> splits = {};
      for (String memberId in _selectedGroup!.members) {
        splits[memberId] = splitAmount;
      }

      setState(() {
        _splitAmounts = splits;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        final amount = double.parse(_amountController.text);

        Expense expense = Expense(
          id: widget.expense?.id ?? '',
          title: _titleController.text,
          amount: amount,
          date: _selectedDate,
          category: _selectedCategory,
          userId: userId,
          groupId: _isSplitBill ? _selectedGroup?.id : null,
          splitDetails: _isSplitBill ? _splitAmounts : null,
        );

        if (widget.expense == null) {
          await _expenseService.addExpense(expense);
        } else {
          await _expenseService.updateExpense(expense);
        }

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving expense: $e')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (_isSplitBill) {
                            _updateSplitAmounts();
                          }
                        },
                      ),
                      SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: _selectedCategory,
                        items:
                            _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      SizedBox(height: 24),

                      // Split bill section
                      SwitchListTile(
                        title: Text('Split Bill'),
                        subtitle: Text('Split this expense with a group'),
                        value: _isSplitBill,
                        onChanged: (value) {
                          setState(() {
                            _isSplitBill = value;
                            if (!value) {
                              _selectedGroup = null;
                              _splitAmounts.clear();
                            }
                          });
                        },
                      ),

                      if (_isSplitBill) ...[
                        SizedBox(height: 16),

                        DropdownButtonFormField<Group>(
                          decoration: InputDecoration(
                            labelText: 'Select Group',
                            prefixIcon: Icon(Icons.group),
                          ),
                          value:
                              _selectedGroup == null
                                  ? null
                                  : _userGroups.firstWhere(
                                    (group) => group.id == _selectedGroup!.id,
                                    orElse:
                                        () =>
                                            _selectedGroup!, // safe because _selectedGroup is not null here
                                  ),
                          items: [
                            if (_selectedGroup != null &&
                                !_userGroups.any(
                                  (g) => g.id == _selectedGroup!.id,
                                ))
                              DropdownMenuItem(
                                value: _selectedGroup,
                                child: Text(_selectedGroup!.name),
                              ),
                            ..._userGroups.map((group) {
                              return DropdownMenuItem(
                                value: group,
                                child: Text(group.name),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedGroup = value;
                              });
                              _loadGroupDetails(value.id);
                              _updateSplitAmounts();
                            }
                          },
                          validator: (value) {
                            if (_isSplitBill && value == null) {
                              return 'Please select a group';
                            }
                            return null;
                          },
                        ),

                        if (_selectedGroup != null &&
                            _groupMembers.isNotEmpty) ...[
                          SizedBox(height: 24),
                          Text(
                            'Split Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          ...List.generate(_groupMembers.length, (index) {
                            final member = _groupMembers[index];
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                    child: Text(
                                      member.name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      member.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\₹${(_splitAmounts[member.id] ?? 0).toInt()}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],

                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveExpense,
                        child: Text(
                          widget.expense == null
                              ? 'Add Expense'
                              : 'Update Expense',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

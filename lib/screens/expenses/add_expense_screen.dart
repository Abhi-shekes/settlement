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
  bool _isCustomSplit = false;

  // Split type selection
  String _splitType = 'group'; // 'group' or 'individual'

  // Group split variables
  Group? _selectedGroup;
  List<Group> _userGroups = [];
  List<UserProfile> _groupMembers = [];

  // Individual split variables
  UserProfile? _selectedFriend;
  List<UserProfile> _userFriends = [];
  bool _isIndividualCustomSplit = false;

  Map<String, double> _splitAmounts = {};
  Map<String, TextEditingController> _splitControllers = {};
  double _remainingAmount = 0;
  double _totalAmount = 0;

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
    _loadFriends();

    // If editing an existing expense
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _selectedDate = widget.expense!.date;
      _selectedCategory = widget.expense!.category;
      _totalAmount = widget.expense!.amount;

      if (widget.expense!.groupId != null) {
        _isSplitBill = true;
        _splitType = 'group';
        _loadGroupDetails(widget.expense!.groupId!);
        _splitAmounts = widget.expense!.splitDetails ?? {};

        // Check if it's a custom split
        if (_splitAmounts.isNotEmpty) {
          double firstValue = _splitAmounts.values.first;
          _isCustomSplit = _splitAmounts.values.any(
            (value) => value != firstValue,
          );
        }
      } else if (widget.expense!.splitDetails != null &&
          widget.expense!.splitDetails!.length == 2) {
        // This is likely an individual split
        _isSplitBill = true;
        _splitType = 'individual';
        _loadIndividualSplitDetails();
      }
    }

    // Listen for changes to the amount
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _titleController.dispose();
    _splitControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _onAmountChanged() {
    if (_amountController.text.isNotEmpty) {
      setState(() {
        _totalAmount = double.tryParse(_amountController.text) ?? 0;
      });
      if (_isSplitBill) {
        if (_splitType == 'group') {
          if (_isCustomSplit) {
            _updateRemainingAmount();
          } else {
            _updateEqualSplitAmounts();
          }
        } else if (_splitType == 'individual') {
          _updateIndividualSplitAmount();
        }
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

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendService.getFriends();
      if (mounted) {
        setState(() {
          _userFriends = friends;
        });
      }
    } catch (e) {
      print('Error loading friends: $e');
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

            // Initialize controllers for each member
            if (!_splitControllers.containsKey(memberId)) {
              double splitAmount = _splitAmounts[memberId] ?? 0;
              _splitControllers[memberId] = TextEditingController(
                text: splitAmount > 0 ? splitAmount.toStringAsFixed(2) : '',
              );
            }
          }
        }

        if (mounted) {
          setState(() {
            _groupMembers = members;
          });

          if (_isCustomSplit) {
            _updateRemainingAmount();
          } else {
            _updateEqualSplitAmounts();
          }
        }
      }
    } catch (e) {
      print('Error loading group details: $e');
    }
  }

  Future<void> _loadIndividualSplitDetails() async {
    try {
      // Find the friend ID (not the current user)
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String? friendId;

      for (String userId in widget.expense!.splitDetails!.keys) {
        if (userId != currentUserId) {
          friendId = userId;
          break;
        }
      }

      if (friendId != null) {
        final friend = await _friendService.getUserProfile(friendId);
        if (friend != null && mounted) {
          setState(() {
            _selectedFriend = friend;
          });

          // Initialize the split controllers
          double friendSplitAmount = _splitAmounts[friendId] ?? 0;
          double userSplitAmount = _splitAmounts[currentUserId] ?? 0;

          // Check if it's a custom split
          if ((friendSplitAmount - userSplitAmount).abs() > 0.01) {
            setState(() {
              _isIndividualCustomSplit = true;
            });
          }

          // Initialize controllers
          if (!_splitControllers.containsKey(friendId)) {
            _splitControllers[friendId] = TextEditingController(
              text:
                  friendSplitAmount > 0
                      ? friendSplitAmount.toStringAsFixed(2)
                      : '',
            );
          }

          if (!_splitControllers.containsKey(currentUserId)) {
            _splitControllers[currentUserId] = TextEditingController(
              text:
                  userSplitAmount > 0 ? userSplitAmount.toStringAsFixed(2) : '',
            );
          }

          if (_isIndividualCustomSplit) {
            _updateIndividualSplitAmount();
          } else {
            _updateIndividualSplitAmount();
          }
        }
      }
    } catch (e) {
      print('Error loading individual split details: $e');
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

  void _updateEqualSplitAmounts() {
    if (_selectedGroup != null && _amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final memberCount = _selectedGroup!.members.length;
      final splitAmount = memberCount > 0 ? amount / memberCount : 0;

      Map<String, double> splits = {};
      for (String memberId in _selectedGroup!.members) {
        splits[memberId] = splitAmount.toDouble();

        // Update the text controllers
        if (_splitControllers.containsKey(memberId)) {
          _splitControllers[memberId]!.text = splitAmount.toStringAsFixed(2);
        } else {
          _splitControllers[memberId] = TextEditingController(
            text: splitAmount.toStringAsFixed(2),
          );
        }
      }

      setState(() {
        _splitAmounts = splits;
        _remainingAmount = 0; // Equal split means no remaining amount
      });
    }
  }

  void _updateIndividualSplitAmount() {
    if (_selectedFriend != null && _amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      if (!_isIndividualCustomSplit) {
        // Equal 50/50 split
        final splitAmount = amount / 2;

        Map<String, double> splits = {};
        splits[currentUserId] = splitAmount;
        splits[_selectedFriend!.id] = splitAmount;

        // Update the text controller for the friend
        if (_splitControllers.containsKey(_selectedFriend!.id)) {
          _splitControllers[_selectedFriend!.id]!.text = splitAmount
              .toStringAsFixed(2);
        } else {
          _splitControllers[_selectedFriend!.id] = TextEditingController(
            text: splitAmount.toStringAsFixed(2),
          );
        }

        // Also create a controller for the current user
        if (!_splitControllers.containsKey(currentUserId)) {
          _splitControllers[currentUserId] = TextEditingController(
            text: splitAmount.toStringAsFixed(2),
          );
        } else {
          _splitControllers[currentUserId]!.text = splitAmount.toStringAsFixed(
            2,
          );
        }

        setState(() {
          _splitAmounts = splits;
          _remainingAmount = 0;
        });
      } else {
        // For custom split, we calculate the remaining amount
        double allocatedAmount = 0;

        // Initialize with default values if not set
        if (!_splitAmounts.containsKey(_selectedFriend!.id)) {
          _splitAmounts[_selectedFriend!.id] = 0;
        }

        if (!_splitAmounts.containsKey(currentUserId)) {
          _splitAmounts[currentUserId] = 0;
        }

        // Calculate allocated amount
        allocatedAmount =
            (_splitAmounts[_selectedFriend!.id] ?? 0) +
            (_splitAmounts[currentUserId] ?? 0);

        setState(() {
          _remainingAmount = amount - allocatedAmount;
        });
      }
    }
  }

  void _updateRemainingAmount() {
    if (_selectedGroup != null && _amountController.text.isNotEmpty) {
      final totalAmount = double.tryParse(_amountController.text) ?? 0;
      double allocatedAmount = 0;

      // Calculate the sum of all allocated amounts
      _splitAmounts.forEach((_, amount) {
        allocatedAmount += amount;
      });

      setState(() {
        _remainingAmount = totalAmount - allocatedAmount;
      });
    }
  }

  void _updateSplitAmount(String memberId, String value) {
    double? amount = double.tryParse(value);
    if (amount != null) {
      setState(() {
        _splitAmounts[memberId] = amount;
        if (_splitType == 'group') {
          _isCustomSplit = true;
          _updateRemainingAmount();
        }
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      // Additional validation for split amounts
      if (_isSplitBill) {
        double totalSplit = 0;
        _splitAmounts.forEach((_, amount) {
          totalSplit += amount;
        });

        final totalAmount = double.parse(_amountController.text);
        if ((totalSplit - totalAmount).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'The sum of split amounts must equal the total expense amount',
              ),
            ),
          );
          return;
        }
      }

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
          groupId:
              (_isSplitBill && _splitType == 'group')
                  ? _selectedGroup?.id
                  : null,
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

  void _updateIndividualSplitValue(String userId, String value) {
    double? amount = double.tryParse(value);
    if (amount != null) {
      setState(() {
        _splitAmounts[userId] = amount;
        _isIndividualCustomSplit = true;
      });
      _updateIndividualSplitAmount();
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
                        subtitle: Text('Split this expense with others'),
                        value: _isSplitBill,
                        onChanged: (value) {
                          setState(() {
                            _isSplitBill = value;
                            if (!value) {
                              _selectedGroup = null;
                              _selectedFriend = null;
                              _splitAmounts.clear();
                              _isCustomSplit = false;
                            }
                          });
                        },
                      ),

                      if (_isSplitBill) ...[
                        SizedBox(height: 16),

                        // Split type selection
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text('With Group'),
                                value: 'group',
                                groupValue: _splitType,
                                onChanged: (value) {
                                  setState(() {
                                    _splitType = value!;
                                    _selectedFriend = null;
                                    _splitAmounts.clear();
                                    _isCustomSplit = false;
                                    if (_selectedGroup != null) {
                                      _updateEqualSplitAmounts();
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text('With Friend'),
                                value: 'individual',
                                groupValue: _splitType,
                                onChanged: (value) {
                                  setState(() {
                                    _splitType = value!;
                                    _selectedGroup = null;
                                    _splitAmounts.clear();
                                    _isCustomSplit = false;
                                    if (_selectedFriend != null) {
                                      _updateIndividualSplitAmount();
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Group selection (if split type is group)
                        if (_splitType == 'group') ...[
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
                                  _isCustomSplit = false;
                                });
                                _loadGroupDetails(value.id);
                              }
                            },
                            validator: (value) {
                              if (_isSplitBill &&
                                  _splitType == 'group' &&
                                  value == null) {
                                return 'Please select a group';
                              }
                              return null;
                            },
                          ),

                          if (_selectedGroup != null &&
                              _groupMembers.isNotEmpty) ...[
                            SizedBox(height: 24),

                            // Split options
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Split Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.refresh),
                                      label: Text('Equal Split'),
                                      onPressed: () {
                                        setState(() {
                                          _isCustomSplit = false;
                                        });
                                        _updateEqualSplitAmounts();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Remaining amount indicator
                            if (_isCustomSplit) ...[
                              Container(
                                padding: EdgeInsets.all(8),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color:
                                      _remainingAmount.abs() < 0.01
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        _remainingAmount.abs() < 0.01
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _remainingAmount.abs() < 0.01
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      color:
                                          _remainingAmount.abs() < 0.01
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _remainingAmount.abs() < 0.01
                                            ? 'All amount allocated'
                                            : _remainingAmount > 0
                                            ? 'Remaining: ₹${_remainingAmount.toStringAsFixed(2)}'
                                            : 'Over-allocated: ₹${(-_remainingAmount).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color:
                                              _remainingAmount.abs() < 0.01
                                                  ? Colors.green
                                                  : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Member split list
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
                                        member.name
                                            .substring(0, 1)
                                            .toUpperCase(),
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
                                    Container(
                                      width: 100,
                                      child: TextFormField(
                                        controller:
                                            _splitControllers[member.id],
                                        decoration: InputDecoration(
                                          prefixText: '₹',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged:
                                            (value) => _updateSplitAmount(
                                              member.id,
                                              value,
                                            ),
                                        validator: (value) {
                                          if (_isSplitBill &&
                                              _splitType == 'group' &&
                                              (value == null ||
                                                  value.isEmpty)) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],

                        // Friend selection (if split type is individual)
                        if (_splitType == 'individual') ...[
                          DropdownButtonFormField<UserProfile>(
                            decoration: InputDecoration(
                              labelText: 'Select Friend',
                              prefixIcon: Icon(Icons.person),
                            ),
                            value: _selectedFriend,
                            items:
                                _userFriends.map((friend) {
                                  return DropdownMenuItem(
                                    value: friend,
                                    child: Text(friend.name),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedFriend = value;
                                });
                                _updateIndividualSplitAmount();
                              }
                            },
                            validator: (value) {
                              if (_isSplitBill &&
                                  _splitType == 'individual' &&
                                  value == null) {
                                return 'Please select a friend';
                              }
                              return null;
                            },
                          ),

                          if (_selectedFriend != null) ...[
                            SizedBox(height: 24),

                            // Split options
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Split Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.refresh),
                                      label: Text('Equal Split'),
                                      onPressed: () {
                                        setState(() {
                                          _isIndividualCustomSplit = false;
                                        });
                                        _updateIndividualSplitAmount();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Remaining amount indicator for custom split
                            if (_isIndividualCustomSplit) ...[
                              Container(
                                padding: EdgeInsets.all(8),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color:
                                      _remainingAmount.abs() < 0.01
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        _remainingAmount.abs() < 0.01
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _remainingAmount.abs() < 0.01
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      color:
                                          _remainingAmount.abs() < 0.01
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _remainingAmount.abs() < 0.01
                                            ? 'All amount allocated'
                                            : _remainingAmount > 0
                                            ? 'Remaining: ₹${_remainingAmount.toStringAsFixed(2)}'
                                            : 'Over-allocated: ₹${(-_remainingAmount).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color:
                                              _remainingAmount.abs() < 0.01
                                                  ? Colors.green
                                                  : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Show the split amount for the user and friend
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                children: [
                                  // Current user's split
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.2),
                                        child: Text(
                                          'You',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'You',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 100,
                                        child: TextFormField(
                                          controller:
                                              _splitControllers[FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .uid],
                                          decoration: InputDecoration(
                                            prefixText: '₹',
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged:
                                              (value) =>
                                                  _updateIndividualSplitValue(
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser!
                                                        .uid,
                                                    value,
                                                  ),
                                          validator: (value) {
                                            if (_isSplitBill &&
                                                _splitType == 'individual' &&
                                                (value == null ||
                                                    value.isEmpty)) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  // Friend's split
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.2),
                                        child: Text(
                                          _selectedFriend!.name
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedFriend!.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 100,
                                        child: TextFormField(
                                          controller:
                                              _splitControllers[_selectedFriend!
                                                  .id],
                                          decoration: InputDecoration(
                                            prefixText: '₹',
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged:
                                              (value) =>
                                                  _updateIndividualSplitValue(
                                                    _selectedFriend!.id,
                                                    value,
                                                  ),
                                          validator: (value) {
                                            if (_isSplitBill &&
                                                _splitType == 'individual' &&
                                                (value == null ||
                                                    value.isEmpty)) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),

                            // Information about the split
                            if (!_isIndividualCustomSplit) ...[
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'The expense is split equally between you and ${_selectedFriend!.name}',
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.purple,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Custom split amounts applied. Make sure the total equals ₹${_totalAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.purple[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ],

                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveExpense,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          widget.expense == null
                              ? 'Add Expense'
                              : 'Update Expense',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

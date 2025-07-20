import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/split_model.dart';
import '../../models/user_model.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';

class AddGroupExpenseWithSplitScreen extends StatefulWidget {
  final GroupModel group;

  const AddGroupExpenseWithSplitScreen({super.key, required this.group});

  @override
  State<AddGroupExpenseWithSplitScreen> createState() =>
      _AddGroupExpenseWithSplitScreenState();
}

class _AddGroupExpenseWithSplitScreenState
    extends State<AddGroupExpenseWithSplitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  final _tagController = TextEditingController();
  bool _isLoading = false;

  // Split functionality
  bool _shouldSplit = true;
  SplitType _splitType = SplitType.equal;
  Map<String, bool> _selectedMembers = {};
  Map<String, double> _customAmounts = {};
  Map<String, UserModel> _memberDetails = {};

  @override
  void initState() {
    super.initState();
    _initializeMembers();
    _loadMemberDetails();
  }

  void _initializeMembers() {
    // Initialize all members as selected by default
    for (String memberId in widget.group.allMemberIds) {
      _selectedMembers[memberId] = true;
      _customAmounts[memberId] = 0.0;
    }
  }

  Future<void> _loadMemberDetails() async {
    final authService = context.read<AuthService>();
    for (String memberId in widget.group.allMemberIds) {
      final user = await authService.getUserById(memberId);
      if (user != null) {
        setState(() {
          _memberDetails[memberId] = user;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _updateCustomAmounts() {
    if (_splitType == SplitType.equal) {
      final selectedCount =
          _selectedMembers.values.where((selected) => selected).length;
      if (selectedCount > 0) {
        final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
        final equalAmount = totalAmount / selectedCount;

        setState(() {
          for (String memberId in _selectedMembers.keys) {
            if (_selectedMembers[memberId]!) {
              _customAmounts[memberId] = equalAmount;
            } else {
              _customAmounts[memberId] = 0.0;
            }
          }
        });
      }
    }
  }

  bool _validateSplit() {
    if (!_shouldSplit) return true;

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final splitTotal = _customAmounts.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );

    return (totalAmount - splitTotal).abs() <
        0.01; // Allow for small rounding differences
  }

  Future<void> _saveExpenseWithSplit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_shouldSplit && !_validateSplit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Split amounts must equal the total expense amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final groupService = context.read<GroupService>();
    final expenseService = context.read<ExpenseService>();

    if (authService.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create the expense
      final expense = ExpenseModel(
        id: const Uuid().v4(),
        userId: authService.currentUser!.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        createdAt: DateTime.now(),
        groupId: widget.group.id,
      );

      // Add expense to group
      await groupService.addGroupExpense(widget.group.id, expense);

      // Create split if enabled
      if (_shouldSplit) {
        final selectedMemberIds =
            _selectedMembers.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();

        final split = SplitModel(
          id: const Uuid().v4(),
          title: expense.title, // Required by model
          description: expense.description, // Required by model
          totalAmount: expense.amount, // From expense
          paidBy:
              authService.currentUser!.uid, // Correct field name (was payerId)
          participants:
              selectedMemberIds, // Correct field name (was participantIds)
          splitType: _splitType,
          splitAmounts: Map.fromEntries(
            // Correct field name (was amounts)
            selectedMemberIds.map(
              (id) => MapEntry(id, _customAmounts[id] ?? 0.0),
            ),
          ),
          createdAt: DateTime.now(),
          groupId: widget.group.id,
          notes: '', // Add required field
          isFullySettled: false, // Correct field name (was isSettled)
          settlements: [], // Required field
        );

        await groupService.createSplit(split);
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _shouldSplit
                  ? 'Group expense with split added successfully!'
                  : 'Group expense added successfully!',
            ),
            backgroundColor: const Color(0xFF008080),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add & Split - ${widget.group.name}'),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF008080)),
              )
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF008080).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF008080).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF008080).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.group,
                                color: Color(0xFF008080),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.group.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${widget.group.allMemberIds.length} members',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Expense Title',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (_splitType == SplitType.equal) {
                            _updateCustomAmounts();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      DropdownButtonFormField<ExpenseCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items:
                            ExpenseCategory.values.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category.categoryDisplayName),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Split Toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.call_split,
                                  color: const Color(0xFF008080),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Split this expense',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _shouldSplit,
                                  onChanged: (value) {
                                    setState(() {
                                      _shouldSplit = value;
                                      if (value &&
                                          _splitType == SplitType.equal) {
                                        _updateCustomAmounts();
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF008080),
                                ),
                              ],
                            ),
                            if (_shouldSplit) ...[
                              const SizedBox(height: 16),

                              // Split Type Selection
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<SplitType>(
                                      title: const Text('Equal Split'),
                                      value: SplitType.equal,
                                      groupValue: _splitType,
                                      onChanged: (value) {
                                        setState(() {
                                          _splitType = value!;
                                          _updateCustomAmounts();
                                        });
                                      },
                                      activeColor: const Color(0xFF008080),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<SplitType>(
                                      title: const Text('Custom'),
                                      value: SplitType.unequal,
                                      groupValue: _splitType,
                                      onChanged: (value) {
                                        setState(() {
                                          _splitType = value!;
                                        });
                                      },
                                      activeColor: const Color(0xFF008080),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Member Selection
                              const Text(
                                'Select Members',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),

                              ...widget.group.allMemberIds.map((memberId) {
                                final user = _memberDetails[memberId];
                                final currentUserId =
                                    context
                                        .read<AuthService>()
                                        .currentUser
                                        ?.uid ??
                                    '';
                                final isCurrentUser = memberId == currentUserId;
                                final displayName =
                                    isCurrentUser
                                        ? 'You'
                                        : (user?.displayName ?? 'Loading...');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        _selectedMembers[memberId]!
                                            ? const Color(
                                              0xFF008080,
                                            ).withOpacity(0.1)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          _selectedMembers[memberId]!
                                              ? const Color(0xFF008080)
                                              : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _selectedMembers[memberId],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedMembers[memberId] = value!;
                                            if (!value) {
                                              _customAmounts[memberId] = 0.0;
                                            } else if (_splitType ==
                                                SplitType.equal) {
                                              _updateCustomAmounts();
                                            }
                                          });
                                        },
                                        activeColor: const Color(0xFF008080),
                                      ),
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(
                                          0xFF008080,
                                        ).withOpacity(0.1),
                                        backgroundImage:
                                            user?.photoURL != null
                                                ? NetworkImage(user!.photoURL!)
                                                : null,
                                        child:
                                            user?.photoURL == null
                                                ? Text(
                                                  isCurrentUser
                                                      ? 'Y'
                                                      : (user
                                                                  ?.displayName
                                                                  .isNotEmpty ==
                                                              true
                                                          ? user!.displayName[0]
                                                              .toUpperCase()
                                                          : 'U'),
                                                  style: const TextStyle(
                                                    color: Color(0xFF008080),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                )
                                                : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (_selectedMembers[memberId]!) ...[
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            initialValue:
                                                (_customAmounts[memberId] ??
                                                        0.0)
                                                    .toStringAsFixed(2),
                                            decoration: const InputDecoration(
                                              prefixText: '₹',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            readOnly:
                                                _splitType == SplitType.equal,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            onChanged: (value) {
                                              final amount =
                                                  double.tryParse(value) ?? 0.0;
                                              setState(() {
                                                _customAmounts[memberId] =
                                                    amount;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),

                              // Split Summary
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF008080,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Split:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₹${_customAmounts.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF008080),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveExpenseWithSplit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008080),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _shouldSplit
                                ? 'Add Expense & Split'
                                : 'Add Group Expense',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

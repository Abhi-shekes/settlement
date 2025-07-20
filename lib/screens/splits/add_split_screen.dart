import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/split_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';

class AddSplitScreen extends StatefulWidget {
  const AddSplitScreen({super.key});

  @override
  State<AddSplitScreen> createState() => _AddSplitScreenState();
}

class _AddSplitScreenState extends State<AddSplitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();

  SplitType _splitType = SplitType.equal;
  String? _selectedGroupId;
  List<UserModel> _friends = [];
  List<String> _selectedFriendIds = [];
  Map<String, double> _customAmounts = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final friends = await context.read<AuthService>().getFriends();
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
        _customAmounts.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
        if (_splitType == SplitType.unequal) {
          _customAmounts[friendId] = 0.0;
          // Also initialize current user's amount if not already done
          final currentUserId = context.read<AuthService>().currentUser!.uid;
          if (!_customAmounts.containsKey(currentUserId)) {
            _customAmounts[currentUserId] = 0.0;
          }
        }
      }
    });
  }

  void _updateCustomAmount(String friendId, double amount) {
    setState(() {
      _customAmounts[friendId] = amount;
    });
  }

  void _calculateEqualSplits() {
    if (_amountController.text.isEmpty) return;

    final totalAmount = double.parse(_amountController.text);
    final currentUserId = context.read<AuthService>().currentUser!.uid;
    final participants = [currentUserId, ..._selectedFriendIds];
    final perPersonAmount = totalAmount / participants.length;

    _customAmounts.clear();
    for (final participantId in participants) {
      _customAmounts[participantId] = perPersonAmount;
    }
    setState(() {}); // Trigger rebuild to update UI
  }

  Future<void> _saveSplit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate participants
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one friend to split with'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate custom amounts for unequal splits
    if (_splitType == SplitType.unequal) {
      double totalCustomAmount = _customAmounts.values.fold(
        0,
        (sum, amount) => sum + amount,
      );
      double totalAmount = double.parse(_amountController.text);

      if ((totalCustomAmount - totalAmount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The sum of individual amounts must equal the total amount',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // For equal splits, calculate the amounts
      _calculateEqualSplits();
    }

    final authService = context.read<AuthService>();
    final groupService = context.read<GroupService>();
    final currentUserId = authService.currentUser!.uid;

    // Create participants list with current user
    final participants = [currentUserId, ..._selectedFriendIds];

    final split = SplitModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      totalAmount: double.parse(_amountController.text),
      paidBy: currentUserId, // Current user paid
      participants: participants,
      splitType: _splitType,
      splitAmounts: _customAmounts,
      createdAt: DateTime.now(),
      groupId: _selectedGroupId,
      notes: _notesController.text.trim(),
    );

    try {
      setState(() {
        _isLoading = true;
      });

      await groupService.createSplit(split);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split created successfully!'),
            backgroundColor: Color(0xFF008080),
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
            content: Text('Error creating split: $e'),
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
        title: const Text('Split a Bill'),
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
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Split Title',
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
                          labelText: 'Total Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.number,
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
                        onChanged: (_) {
                          if (_splitType == SplitType.equal &&
                              _selectedFriendIds.isNotEmpty) {
                            _calculateEqualSplits();
                          }
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
                      ),
                      const SizedBox(height: 24),

                      // Split Type
                      const Text(
                        'Split Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF008080),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSplitTypeOption(
                              SplitType.equal,
                              'Equal Split',
                              'Everyone pays the same amount',
                              Icons.balance,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSplitTypeOption(
                              SplitType.unequal,
                              'Unequal Split',
                              'Customize amount for each person',
                              Icons.tune,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Select Friends
                      const Text(
                        'Select Friends',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF008080),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_friends.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'No friends found. Add friends from the profile section.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _friends.length,
                          itemBuilder: (context, index) {
                            final friend = _friends[index];
                            final isSelected = _selectedFriendIds.contains(
                              friend.uid,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color:
                                      isSelected
                                          ? const Color(0xFF008080)
                                          : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _toggleFriendSelection(friend.uid),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(
                                          0xFF008080,
                                        ).withOpacity(0.1),
                                        child: Text(
                                          friend.displayName.isNotEmpty
                                              ? friend.displayName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF008080),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              friend.displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              friend.email,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Checkbox(
                                        value: isSelected,
                                        onChanged:
                                            (_) => _toggleFriendSelection(
                                              friend.uid,
                                            ),
                                        activeColor: const Color(0xFF008080),
                                      ),
                                      if (isSelected &&
                                          _splitType == SplitType.unequal)
                                        SizedBox(
                                          width: 100,
                                          child: TextFormField(
                                            initialValue:
                                                _customAmounts[friend.uid]
                                                    ?.toString() ??
                                                '0',
                                            decoration: const InputDecoration(
                                              prefixText: '₹',
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              final amount =
                                                  double.tryParse(value) ?? 0.0;
                                              _updateCustomAmount(
                                                friend.uid,
                                                amount,
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      // Current User Amount (for unequal splits)
                      if (_splitType == SplitType.unequal &&
                          _selectedFriendIds.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 16, bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF008080).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF008080)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF008080),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF008080),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      initialValue:
                                          _customAmounts[context
                                                  .read<AuthService>()
                                                  .currentUser!
                                                  .uid]
                                              ?.toString() ??
                                          '0',
                                      decoration: const InputDecoration(
                                        prefixText: '₹',
                                        labelText: 'Your amount',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final amount =
                                            double.tryParse(value) ?? 0.0;
                                        final currentUserId =
                                            context
                                                .read<AuthService>()
                                                .currentUser!
                                                .uid;
                                        _updateCustomAmount(
                                          currentUserId,
                                          amount,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveSplit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008080),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Create Split',
                            style: TextStyle(
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

  Widget _buildSplitTypeOption(
    SplitType type,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _splitType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _splitType = type;
          if (type == SplitType.equal && _selectedFriendIds.isNotEmpty) {
            _calculateEqualSplits();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF008080).withOpacity(0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF008080) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF008080) : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF008080) : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

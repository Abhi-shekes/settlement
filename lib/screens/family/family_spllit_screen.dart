import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/split_model.dart';
import '../../models/family_member_model.dart';
import '../../services/family_service.dart';
import '../../services/auth_service.dart';

class FamilySplitScreen extends StatefulWidget {
  const FamilySplitScreen({super.key});

  @override
  State<FamilySplitScreen> createState() => _FamilySplitScreenState();
}

class _FamilySplitScreenState extends State<FamilySplitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  SplitType _splitType = SplitType.equal;
  List<String> _selectedMemberIds = [];
  Map<String, double> _customAmounts = {};
  bool _isLoading = false;
  String _selectedCategory = 'Household';

  final List<String> _familyCategories = [
    'Household',
    'Groceries',
    'Utilities',
    'Childcare',
    'Education',
    'Healthcare',
    'Entertainment',
    'Dining Out',
    'Transportation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<FamilyService>().loadFamilyMembers();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading family members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
        _customAmounts.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
        if (_splitType == SplitType.unequal) {
          _customAmounts[memberId] = 0.0;
        }
      }
    });
  }

  void _updateCustomAmount(String memberId, double amount) {
    setState(() {
      _customAmounts[memberId] = amount;
    });
  }

  void _calculateEqualSplits() {
    if (_amountController.text.isEmpty) return;

    final totalAmount = double.parse(_amountController.text);
    final currentUserId = context.read<AuthService>().currentUser!.uid;
    final participants = [currentUserId, ..._selectedMemberIds];
    final perPersonAmount = totalAmount / participants.length;

    _customAmounts.clear();
    for (final participantId in participants) {
      _customAmounts[participantId] = perPersonAmount;
    }
    setState(() {});
  }

  Future<void> _saveFamilySplit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one family member'),
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
      _calculateEqualSplits();
    }

    final authService = context.read<AuthService>();
    final familyService = context.read<FamilyService>();
    final currentUserId = authService.currentUser!.uid;

    final participants = [currentUserId, ..._selectedMemberIds];

    final split = SplitModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      totalAmount: double.parse(_amountController.text),
      paidBy: currentUserId,
      participants: participants,
      splitType: _splitType,
      splitAmounts: _customAmounts,
      createdAt: DateTime.now(),
      groupId: null, // Family splits don't belong to groups
      notes: _notesController.text.trim(),
    );

    try {
      setState(() {
        _isLoading = true;
      });

      await familyService.createFamilySplit(split);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Family split created successfully!'),
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
            content: Text('Error creating family split: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyMembers = context.watch<FamilyService>().familyMembers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Family Bill'),
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
                      // Family Split Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF008080), Color(0xFF20B2AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.family_restroom,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Family Expense Split',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Split expenses among family members',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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

                      // Category
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF008080),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items:
                            _familyCategories.map((category) {
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
                              _selectedMemberIds.isNotEmpty) {
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
                              'Everyone pays equally',
                              Icons.balance,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSplitTypeOption(
                              SplitType.unequal,
                              'Custom Split',
                              'Set custom amounts',
                              Icons.tune,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Family Members
                      const Text(
                        'Select Family Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF008080),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (familyMembers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.family_restroom,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No family members found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add family members to start splitting expenses',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/add-family-member',
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF008080),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Add Family Member'),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: familyMembers.length,
                          itemBuilder: (context, index) {
                            final member = familyMembers[index];
                            final isSelected = _selectedMemberIds.contains(
                              member.id,
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
                                onTap: () => _toggleMemberSelection(member.id),
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
                                        backgroundImage:
                                            member.photoUrl != null
                                                ? NetworkImage(member.photoUrl!)
                                                : null,
                                        child:
                                            member.photoUrl == null
                                                ? Text(
                                                  member.name.isNotEmpty
                                                      ? member.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Color(0xFF008080),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                                : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              member.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              member.roleDisplayName,
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
                                            (_) => _toggleMemberSelection(
                                              member.id,
                                            ),
                                        activeColor: const Color(0xFF008080),
                                      ),
                                      if (isSelected &&
                                          _splitType == SplitType.unequal)
                                        SizedBox(
                                          width: 100,
                                          child: TextFormField(
                                            initialValue:
                                                _customAmounts[member.id]
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
                                                member.id,
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
                          _selectedMemberIds.isNotEmpty)
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
                                  const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Color(0xFF008080),
                                    child: Icon(
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

                      const SizedBox(height: 16),

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
                          onPressed: _saveFamilySplit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008080),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Create Family Split',
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
          if (type == SplitType.equal && _selectedMemberIds.isNotEmpty) {
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

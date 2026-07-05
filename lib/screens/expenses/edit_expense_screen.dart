import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/account_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final ExpenseModel expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;

  late ExpenseCategory _selectedCategory;
  String? _selectedAccountId;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _descriptionController = TextEditingController(
      text: widget.expense.description,
    );
    _amountController = TextEditingController(
      text: widget.expense.amount.toString(),
    );
    _selectedCategory = widget.expense.category;
    _selectedAccountId = widget.expense.accountId;
    context.read<AccountService>().loadUserAccounts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final expenseService = context.read<ExpenseService>();

    final updatedExpense = ExpenseModel(
      id: widget.expense.id,
      userId: widget.expense.userId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text),
      category: _selectedCategory,
      createdAt: widget.expense.createdAt,
      groupId: widget.expense.groupId,
      isSettled: widget.expense.isSettled,
      accountId: _selectedAccountId,
    );

    try {
      await expenseService.updateExpense(updatedExpense);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully!'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating expense: $e'),
            backgroundColor: const Color(0xFFF97316),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Expense')),
      body: Form(
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
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items:
                    ExpenseCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category.toString().split('.').last.toUpperCase(),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Account (paid from)
              Consumer<AccountService>(
                builder: (context, accountService, child) {
                  if (accountService.accounts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (_selectedAccountId != null &&
                      accountService.getAccountById(_selectedAccountId) ==
                          null) {
                    _selectedAccountId = null;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Paid from',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...accountService.accounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Row(
                              children: [
                                Icon(a.icon, size: 18, color: a.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${a.name} (${a.formattedBalance})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedAccountId = value);
                      },
                    ),
                  );
                },
              ),

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
              const SizedBox(height: 16),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateExpense,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Update Expense',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/expense_model.dart';
import '../../services/recurring_service.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';

/// Creates a new recurring rule, or edits/deletes an existing one when [rule]
/// is provided.
class AddRecurringScreen extends StatefulWidget {
  final RecurringTransactionModel? rule;

  const AddRecurringScreen({super.key, this.rule});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends State<AddRecurringScreen> {
  static const _teal = Color(0xFF0F766E);
  static const _coral = Color(0xFFF97316);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late ExpenseCategory _category;
  late RecurrenceFrequency _frequency;
  late DateTime _startDate;
  String? _accountId;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _titleController = TextEditingController(text: r?.title ?? '');
    _amountController = TextEditingController(
      text: r != null ? r.amount.toString() : '',
    );
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _category = r?.category ?? ExpenseCategory.utilities;
    _frequency = r?.frequency ?? RecurrenceFrequency.monthly;
    _startDate = r?.startDate ?? DateTime.now();
    _accountId = r?.accountId;
    context.read<AccountService>().loadUserAccounts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final service = context.read<RecurringService>();
    final uid = context.read<AuthService>().currentUser?.uid;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (uid == null) return;

    final amount = double.parse(_amountController.text.trim());

    try {
      if (_isEditing) {
        await service.updateRule(
          widget.rule!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            amount: amount,
            category: _category,
            frequency: _frequency,
            startDate: _startDate,
            accountId: _accountId,
            clearAccount: _accountId == null,
          ),
        );
      } else {
        final rule = RecurringTransactionModel(
          id: const Uuid().v4(),
          userId: uid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _category,
          accountId: _accountId,
          frequency: _frequency,
          startDate: _startDate,
          // First occurrence is the start date; processDue materialises it once
          // that date has arrived.
          nextDueDate: _startDate,
          createdAt: DateTime.now(),
        );
        await service.addRule(rule);
        // Generate immediately if the start date is already due.
        await service.processDue();
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Rule updated!' : 'Recurring rule added!'),
          backgroundColor: _teal,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _coral),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Rule'),
            content: const Text(
              'Delete this recurring rule? Expenses already generated from it '
              'are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;

    final service = context.read<RecurringService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await service.deleteRule(widget.rule!.id);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Rule deleted')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _coral),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring' : 'New Recurring'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Rent, Netflix, Salary',
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
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
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
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 16),

              // Account
              Consumer<AccountService>(
                builder: (context, accountService, child) {
                  if (accountService.accounts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (_accountId != null &&
                      accountService.getAccountById(_accountId) == null) {
                    _accountId = null;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _accountId,
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
                                    a.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                  );
                },
              ),

              const Text(
                'Repeats',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    RecurrenceFrequency.values.map((f) {
                      final selected = f == _frequency;
                      return ChoiceChip(
                        label: Text(f.displayName),
                        selected: selected,
                        onSelected: (_) => setState(() => _frequency = f),
                        selectedColor: _teal,
                        backgroundColor: _teal.withValues(alpha: 0.10),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : context.colors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _pickStartDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(DateFormat('EEE, MMM d, y').format(_startDate)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isEditing ? 'Save Changes' : 'Create Rule',
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

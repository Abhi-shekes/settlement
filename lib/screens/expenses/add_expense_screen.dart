import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/account_service.dart';
import '../../services/ai_service.dart';
import '../../services/notification_center_service.dart';
import '../../models/app_notification.dart';
import '../../widgets/budget_alert_dialog.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  String? _selectedAccountId;
  bool _suggesting = false;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load budgets when screen initializes
    context.read<BudgetService>().loadUserBudgets();
    final accountService = context.read<AccountService>();
    accountService.loadUserAccounts();
    // Default to the first account if any exist so spending is attributed by
    // default; the user can still switch to "None".
    if (accountService.accounts.isNotEmpty) {
      _selectedAccountId = accountService.accounts.first.id;
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

  Future<void> _suggestCategory() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a title first.')));
      return;
    }
    final ai = context.read<AiService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _suggesting = true);
    try {
      final suggestion = await ai.suggestCategory(
        title: title,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      if (suggestion != null) {
        setState(() => _selectedCategory = suggestion);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Suggested: ${suggestion.categoryDisplayName}'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('api') ||
                    msg.contains('permission') ||
                    msg.contains('not enabled')
                ? 'Enable "Firebase AI Logic" in the Firebase console.'
                : 'AI error: $e',
          ),
          backgroundColor: const Color(0xFFF97316),
        ),
      );
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final expenseService = context.read<ExpenseService>();
    final budgetService = context.read<BudgetService>();
    final notificationCenter = context.read<NotificationCenterService>();

    if (authService.currentUser == null) return;

    // Get amount from controller
    final amount = double.parse(_amountController.text);

    // Check if this expense will exceed budget
    final currentCategorySpending = expenseService
        .getTotalExpenseAmountByCategory(_selectedCategory);
    final budgetCheck = budgetService.checkBudgetExceeded(
      _selectedCategory,
      amount,
      currentCategorySpending,
    );

    // Create the expense
    final expense = ExpenseModel(
      id: const Uuid().v4(),
      userId: authService.currentUser!.uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      createdAt: DateTime.now(),
      accountId: _selectedAccountId,
    );

    try {
      // Save the expense
      await expenseService.addExpense(expense);

      // Emit a budget notification (local push + history) whenever a threshold
      // is crossed — the previously unused half of checkBudgetExceeded.
      if (budgetCheck != null) {
        _emitBudgetNotification(notificationCenter, budgetCheck);
      }

      if (mounted) {
        // Show budget alert if needed
        if (budgetCheck != null) {
          // Show different alerts for exceeded vs approaching
          if (budgetCheck.containsKey('isApproaching') &&
              budgetCheck['isApproaching']) {
            // Approaching budget limit
            showDialog(
              context: context,
              builder:
                  (context) => BudgetAlertDialog(
                    category: budgetCheck['category'],
                    budgetAmount: budgetCheck['budgetAmount'],
                    currentSpending: budgetCheck['currentSpending'],
                    newSpending: budgetCheck['newSpending'],
                    exceededBy: 0, // Not exceeded yet
                    percentage: budgetCheck['percentage'],
                    isApproaching: true,
                  ),
            );
          } else {
            // Exceeded budget
            showDialog(
              context: context,
              builder:
                  (context) => BudgetAlertDialog(
                    category: budgetCheck['category'],
                    budgetAmount: budgetCheck['budgetAmount'],
                    currentSpending: budgetCheck['currentSpending'],
                    newSpending: budgetCheck['newSpending'],
                    exceededBy: budgetCheck['exceededBy'],
                    percentage: budgetCheck['percentage'],
                  ),
            );
          }
        } else {
          // No budget issues, just show success message
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added successfully!'),
              backgroundColor: Color(0xFF0F766E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding expense: $e'),
            backgroundColor: const Color(0xFFF97316),
          ),
        );
      }
    }
  }

  /// Records a budget alert in the notification centre. The heads-up itself is
  /// raised by NotificationCenterService's stream listener (respecting the
  /// budgets preference), so we only write history here. Budget data is
  /// private, so this is done client-side.
  void _emitBudgetNotification(
    NotificationCenterService center,
    Map<String, dynamic> check,
  ) {
    final ExpenseCategory category = check['category'] as ExpenseCategory;
    final name = category.categoryDisplayName;
    final pct = (check['percentage'] as num).round();
    final approaching = check['isApproaching'] == true;

    final title =
        approaching ? 'Approaching $name budget' : '$name budget exceeded';
    final body = approaching
        ? "You've used $pct% of your $name budget this month."
        : "You've spent ₹${(check['newSpending'] as num).round()} — "
            "₹${(check['exceededBy'] as num).round()} over your $name budget.";

    center.addLocal(
      AppNotification(
        id: '',
        type: 'budget',
        category: NotificationCategory.budgets,
        title: title,
        body: body,
        data: const {'type': 'budget', 'category': NotificationCategory.budgets},
        read: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
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
              const SizedBox(height: 8),

              // AI category suggestion
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _suggesting ? null : _suggestCategory,
                  icon:
                      _suggesting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    _suggesting ? 'Suggesting…' : 'Suggest category with AI',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Account (paid from)
              Consumer<AccountService>(
                builder: (context, accountService, child) {
                  if (accountService.accounts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  // Guard against a stale selection (e.g. account deleted).
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

              // Budget Info
              Consumer2<BudgetService, ExpenseService>(
                builder: (context, budgetService, expenseService, child) {
                  final budget = budgetService.getBudgetForCategory(
                    _selectedCategory,
                  );
                  final currentSpending = expenseService
                      .getTotalExpenseAmountByCategory(_selectedCategory);

                  if (budget != null && budget.amount > 0) {
                    // Calculate usage percentage
                    final usagePercentage =
                        (currentSpending / budget.amount) * 100;

                    return Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Budget Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      usagePercentage > 100
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : usagePercentage >= 80
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  usagePercentage > 100
                                      ? 'Exceeded'
                                      : usagePercentage >= 80
                                      ? 'Near Limit'
                                      : 'On Track',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        usagePercentage > 100
                                            ? Colors.red
                                            : usagePercentage >= 80
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monthly Budget: ${budget.formattedAmount}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Spent: ₹${currentSpending.toInt()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value:
                                  usagePercentage > 100
                                      ? 1.0
                                      : usagePercentage / 100,
                              backgroundColor: context.colors.surfaceSunken,
                              color:
                                  usagePercentage > 100
                                      ? Colors.red
                                      : usagePercentage >= 80
                                      ? Colors.orange
                                      : const Color(0xFF0F766E),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adding this expense might ${usagePercentage > 100
                                ? 'further exceed'
                                : usagePercentage >= 80
                                ? 'exceed'
                                : 'affect'} your budget.',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Add Expense',
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

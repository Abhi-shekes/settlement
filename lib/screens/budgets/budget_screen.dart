import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../services/budget_service.dart';
import '../../services/category_service.dart';
import '../../services/expense_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  /// One amount controller per category, keyed by category id so custom
  /// categories (added at runtime) get controllers lazily.
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String categoryId) {
    return _controllers.putIfAbsent(categoryId, () => TextEditingController());
  }

  Future<void> _loadBudgets() async {
    // Capture services before any await so we never touch context across a gap.
    final categoryService = context.read<CategoryService>();
    final budgetService = context.read<BudgetService>();

    // Categories must be loaded before we seed controllers so custom ones show.
    await categoryService.loadUserCategories();
    await budgetService.loadUserBudgets();
    if (!mounted) return;

    for (final category in categoryService.all) {
      final budget = budgetService.getBudgetForCategory(category);
      final controller = _controllerFor(category.id);
      controller.text =
          (budget != null && budget.amount > 0) ? budget.amount.toString() : '';
    }
    setState(() {});
  }

  /// Saves a single category budget. Set [showFeedback] to false when saving
  /// many at once (the "Save All" flow shows a single summary snackbar instead
  /// of one per category).
  Future<void> _saveBudget(
    Category category,
    String value, {
    bool showFeedback = true,
  }) async {
    if (value.isEmpty) return;

    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BudgetService>().setBudget(category, amount);
      if (!showFeedback) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Budget for ${category.name.toUpperCase()} updated'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } catch (e) {
      if (!showFeedback) rethrow;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error updating budget: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        actions: [
          TextButton.icon(
            onPressed: _showCreateCategoryDialog,
            icon: const Icon(Icons.add),
            label: const Text('New category'),
          ),
        ],
      ),
      body: Consumer3<BudgetService, ExpenseService, CategoryService>(
        builder: (
          context,
          budgetService,
          expenseService,
          categoryService,
          child,
        ) {
          if (budgetService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();
          final currentMonth = DateFormat('MMMM yyyy').format(now);

          return RefreshIndicator(
            onRefresh: _loadBudgets,
            color: const Color(0xFF0F766E),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Monthly Budget',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentMonth,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Budget Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Text(
                              'How Budgeting Works',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Set monthly budgets for each expense category\n'
                          '• Add your own categories with "New category"\n'
                          '• Get alerts when you exceed your budget\n'
                          '• Receive notifications when nearing budget limits (80%)\n'
                          '• Leave a budget empty or set to 0 to disable tracking',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Category Budgets
                  const Text(
                    'Category Budgets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...categoryService.all.map((category) {
                    final currentSpending = expenseService
                        .getTotalExpenseAmountByCategory(category);
                    final budget = budgetService.getBudgetForCategory(category);
                    final budgetAmount = budget?.amount ?? 0;

                    double usagePercentage = 0;
                    if (budgetAmount > 0) {
                      usagePercentage = (currentSpending / budgetAmount) * 100;
                      if (usagePercentage > 100) usagePercentage = 100;
                    }

                    Color progressColor;
                    if (budgetAmount > 0 && currentSpending > budgetAmount) {
                      progressColor = Colors.red;
                    } else if (budgetAmount > 0 &&
                        currentSpending >= budgetAmount * 0.8) {
                      progressColor = Colors.orange;
                    } else {
                      progressColor = const Color(0xFF0F766E);
                    }

                    return _buildBudgetCard(
                      category,
                      _controllerFor(category.id),
                      currentSpending,
                      budgetAmount,
                      usagePercentage,
                      progressColor,
                    );
                  }),

                  const SizedBox(height: 24),

                  // Save All Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final categoryService = context.read<CategoryService>();
                        try {
                          for (final entry in _controllers.entries) {
                            final value = entry.value.text.trim();
                            if (value.isNotEmpty) {
                              await _saveBudget(
                                categoryService.byId(entry.key),
                                value,
                                showFeedback: false,
                              );
                            }
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('All budgets updated successfully'),
                              backgroundColor: Color(0xFF0F766E),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error updating budgets: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save All Budgets',
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
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard(
    Category category,
    TextEditingController controller,
    double currentSpending,
    double budgetAmount,
    double usagePercentage,
    Color progressColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (budgetAmount > 0 && currentSpending > budgetAmount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'EXCEEDED',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (budgetAmount > 0 &&
                    currentSpending >= budgetAmount * 0.8 &&
                    currentSpending <= budgetAmount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEAR LIMIT',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                // Custom categories can be removed; built-ins are permanent.
                if (category.isCustom)
                  IconButton(
                    tooltip: 'Delete category',
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.colors.muted,
                      size: 20,
                    ),
                    onPressed: () => _confirmDeleteCategory(category),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Budget Input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Monthly Budget',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          hintText: 'Enter amount',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted:
                            (value) => _saveBudget(category, value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Spending',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹ ${currentSpending.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Budget Progress
            if (budgetAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Used: ${usagePercentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: progressColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    budgetAmount > currentSpending
                        ? 'Remaining: ₹${(budgetAmount - currentSpending).toInt()}'
                        : 'Exceeded by: ₹${(currentSpending - budgetAmount).toInt()}',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          budgetAmount > currentSpending
                              ? Colors.green
                              : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercentage / 100,
                  backgroundColor: context.colors.surfaceSunken,
                  color: progressColor,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Custom category creation ────────────────────────────────────────────────

  Future<void> _showCreateCategoryDialog() async {
    final nameController = TextEditingController();
    int selectedIcon = kCategoryIconPalette.first.codePoint;
    int selectedColor = kCategoryColorPalette.first;
    String? errorText;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('New category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Rent, Gym, Pets',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialog(() => errorText = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Icon', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final icon in kCategoryIconPalette)
                          _pickChip(
                            selected: icon.codePoint == selectedIcon,
                            color: Color(selectedColor),
                            onTap:
                                () => setDialog(
                                  () => selectedIcon = icon.codePoint,
                                ),
                            child: Icon(icon, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Colour', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final colorValue in kCategoryColorPalette)
                          _pickChip(
                            selected: colorValue == selectedColor,
                            color: Color(colorValue),
                            filled: true,
                            onTap:
                                () =>
                                    setDialog(() => selectedColor = colorValue),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final categoryService = context.read<CategoryService>();
                    if (name.isEmpty) {
                      setDialog(() => errorText = 'Enter a name');
                      return;
                    }
                    if (categoryService.nameExists(name)) {
                      setDialog(
                        () => errorText = 'A category with this name exists',
                      );
                      return;
                    }
                    final navigator = Navigator.of(context);
                    try {
                      await categoryService.addCustomCategory(
                        name: name,
                        iconCodePoint: selectedIcon,
                        colorValue: selectedColor,
                      );
                      navigator.pop(true);
                    } catch (e) {
                      setDialog(() => errorText = 'Could not save: $e');
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (created == true && mounted) {
      // A controller for the new category is created lazily on next build.
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category added'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    }
  }

  Widget _pickChip({
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    Widget? child,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2.5,
          ),
        ),
        child:
            child != null
                ? IconTheme(
                  data: IconThemeData(color: color),
                  child: Center(child: child),
                )
                : (selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete "${category.name}"?'),
            content: const Text(
              'This removes the category and its budget. Expenses already logged '
              'under it are kept but will show as an unnamed category.',
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

    final categoryService = context.read<CategoryService>();
    final budgetService = context.read<BudgetService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Remove any budgets tied to this category so nothing is orphaned.
      final orphaned =
          budgetService.budgets
              .where((b) => b.categoryId == category.id)
              .map((b) => b.id)
              .toList();
      for (final id in orphaned) {
        await budgetService.deleteBudget(id);
      }
      await categoryService.deleteCustomCategory(category.id);
      _controllers.remove(category.id)?.dispose();
      if (mounted) setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${category.name}"')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

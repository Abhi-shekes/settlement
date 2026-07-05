import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/category_style.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;
  String _sortBy = 'date'; // 'date', 'amount', 'category'
  bool _sortAscending = false;

  final TextEditingController _searchController = TextEditingController();
  final DateTimeRange _initialDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = _initialDateRange;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshExpenses());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshExpenses() async {
    await context.read<ExpenseService>().loadUserExpenses();
  }

  List<ExpenseModel> _getFilteredExpenses() {
    final expenseService = context.watch<ExpenseService>();
    List<ExpenseModel> filteredExpenses = List.from(expenseService.expenses);

    if (_searchQuery.isNotEmpty) {
      filteredExpenses =
          filteredExpenses.where((expense) {
            return expense.title.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                expense.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
    }

    if (_selectedCategory != null) {
      filteredExpenses =
          filteredExpenses
              .where((expense) => expense.category == _selectedCategory)
              .toList();
    }

    if (_selectedDateRange != null) {
      filteredExpenses =
          filteredExpenses.where((expense) {
            return expense.createdAt.isAfter(_selectedDateRange!.start) &&
                expense.createdAt.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
    }

    filteredExpenses.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'amount':
          result = a.amount.compareTo(b.amount);
          break;
        case 'category':
          result = a.category.toString().compareTo(b.category.toString());
          break;
        case 'date':
        default:
          result = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAscending ? result : -result;
    });

    return filteredExpenses;
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != null ||
      _selectedDateRange != _initialDateRange;

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = null;
      _selectedDateRange = _initialDateRange;
    });
  }

  void _showSortOptions() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sort by', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _buildSortOption('Date', 'date'),
                _buildSortOption('Amount', 'amount'),
                _buildSortOption('Category', 'category'),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order'),
                      ToggleButtons(
                        isSelected: [_sortAscending, !_sortAscending],
                        onPressed: (index) {
                          setState(() => _sortAscending = index == 0);
                          Navigator.pop(sheetContext);
                        },
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        selectedColor: c.onBrand,
                        fillColor: c.brand,
                        color: c.muted,
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 90,
                        ),
                        children: const [Text('Ascending'), Text('Descending')],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, String value) {
    final c = context.colors;
    return ListTile(
      title: Text(title),
      trailing:
          _sortBy == value ? Icon(Icons.check_rounded, color: c.brand) : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _getFilteredExpenses();
    final expenseService = context.watch<ExpenseService>();
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded),
            onPressed: _showSortOptions,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => _buildFilterSheet(),
              );
            },
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search expenses',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: AppChip(
                    label: 'All',
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                ),
                ...ExpenseCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: AppChip(
                      label: category.categoryDisplayName,
                      icon: category.icon,
                      color: category.color,
                      selected: _selectedCategory == category,
                      onTap:
                          () => setState(
                            () =>
                                _selectedCategory =
                                    _selectedCategory == category
                                        ? null
                                        : category,
                          ),
                    ),
                  );
                }),
              ],
            ),
          ),

          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filteredExpenses.length} result${filteredExpenses.length == 1 ? '' : 's'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.muted),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                    ),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child:
                expenseService.isLoading
                    ? const SkeletonList()
                    : filteredExpenses.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _refreshExpenses,
                      color: c.brand,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: filteredExpenses.length,
                        separatorBuilder:
                            (_, __) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder:
                            (context, index) =>
                                _buildExpenseCard(filteredExpenses[index]),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          _refreshExpenses();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildFilterSheet() {
    final c = context.colors;
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Filter expenses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Date range',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _selectedDateRange,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => _selectedDateRange = picked);
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: c.surfaceSunken,
                          border: Border.all(color: c.cardBorder),
                          borderRadius: AppRadii.field,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${DateFormat('MMM d, y').format(_selectedDateRange!.start)} — ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}',
                            ),
                            Icon(Icons.calendar_today_rounded, color: c.brand),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Category',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppChip(
                          label: 'All',
                          selected: _selectedCategory == null,
                          onTap: () {
                            setSheetState(() => _selectedCategory = null);
                            setState(() {});
                          },
                        ),
                        ...ExpenseCategory.values.map((category) {
                          return AppChip(
                            label: category.categoryDisplayName,
                            icon: category.icon,
                            color: category.color,
                            selected: _selectedCategory == category,
                            onTap: () {
                              setSheetState(
                                () =>
                                    _selectedCategory =
                                        _selectedCategory == category
                                            ? null
                                            : category,
                              );
                              setState(() {});
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedDateRange = _initialDateRange;
                                _selectedCategory = null;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.receipt_long_rounded,
      title: _hasActiveFilters ? 'No matches' : 'No expenses yet',
      message:
          _hasActiveFilters
              ? 'Try adjusting your filters to see more.'
              : 'Track your first expense to get started.',
      actionLabel: _hasActiveFilters ? null : 'Add expense',
      onAction:
          _hasActiveFilters
              ? null
              : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              ),
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense) {
    final theme = Theme.of(context);
    final c = context.colors;
    return Material(
      color: c.surfaceElevated,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseDetailScreen(expense: expense),
            ),
          ).then((_) => _refreshExpenses());
        },
        borderRadius: AppRadii.card,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadii.card,
            border: Border.all(color: c.cardBorder),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: expense.category.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  expense.category.icon,
                  color: expense.category.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expense.description.isEmpty
                          ? expense.categoryDisplayName
                          : expense.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    expense.formattedAmount,
                    style: AppTypography.money(
                      fontSize: 15,
                      color: expense.isRefund ? c.positive : c.brand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d').format(expense.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: c.faint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

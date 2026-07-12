import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import '../../services/expense_service.dart';
import '../../services/category_service.dart';
import '../../services/account_service.dart';
import '../../services/recurring_service.dart';
import '../../services/budget_service.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_center_service.dart';
import '../../services/home_widget_service.dart';
import 'dashboard_screen.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../splits/splits_screen.dart';
import '../splits/add_split_screen.dart';
import '../groups/groups_screen.dart';
import '../groups/create_group_screen.dart';
import '../profile/profile_screen.dart';
import '../ai/ai_assistant_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ExpensesScreen(),
    const SplitsScreen(),
    const GroupsScreen(),
    const ProfileScreen(),
  ];

  StreamSubscription<Uri?>? _widgetClickSub;
  bool _widgetListenersAttached = false;

  // Captured provider references for the widget-sync listeners. Saved at attach
  // time so dispose() can detach them without calling context.read (which is
  // unsafe once the element is defunct during unmount).
  ExpenseService? _expenseServiceRef;
  AccountService? _accountServiceRef;
  BudgetService? _budgetServiceRef;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupHomeWidgets();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Capture services before any await so we never touch context across an
      // async gap.
      final accountService = context.read<AccountService>();
      final categoryService = context.read<CategoryService>();
      final expenseService = context.read<ExpenseService>();
      final recurringService = context.read<RecurringService>();
      final budgetService = context.read<BudgetService>();
      final groupService = context.read<GroupService>();
      final notificationCenter = context.read<NotificationCenterService>();
      final uid = context.read<AuthService>().currentUser?.uid;

      // Load custom categories first so expenses/budgets resolve their category
      // (name, icon, colour) as soon as they load.
      await categoryService.loadUserCategories();

      // Load accounts and expenses first, then materialise any due recurring
      // transactions — accounts must be loaded so their balances get adjusted.
      await accountService.loadUserAccounts();
      await expenseService.loadUserExpenses();
      await recurringService.processDue();
      await budgetService.loadUserBudgets();

      groupService.loadUserGroups();
      groupService.loadUserSplits();

      // Push the latest snapshot to the home-screen widgets, and keep them in
      // sync as the underlying data changes.
      _pushWidgets();
      if (!_widgetListenersAttached) {
        _widgetListenersAttached = true;
        _expenseServiceRef = expenseService;
        _accountServiceRef = accountService;
        _budgetServiceRef = budgetService;
        expenseService.addListener(_pushWidgets);
        accountService.addListener(_pushWidgets);
        budgetService.addListener(_pushWidgets);
      }

      // Register this device for push notifications now that we're signed in,
      // start streaming the notification centre, and route any tap that
      // cold-started the app.
      if (uid != null) {
        NotificationService.instance.registerDevice(uid);
        notificationCenter.start(uid);
        NotificationService.instance.routePendingInitialMessage();
      }
    });
  }

  void _pushWidgets() {
    if (!mounted) return;
    HomeWidgetService.update(
      expenses: context.read<ExpenseService>(),
      accounts: context.read<AccountService>(),
      budgets: context.read<BudgetService>(),
    );
  }

  /// Routes taps on the home-screen widgets (cold start + while running).
  void _setupHomeWidgets() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_routeWidgetUri);
    _widgetClickSub = HomeWidget.widgetClicked.listen(_routeWidgetUri);
  }

  void _routeWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (uri.host) {
        case 'add':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          break;
        case 'voice':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AiAssistantScreen(startVoice: true),
            ),
          );
          break;
        case 'assistant':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
          );
          break;
        case 'refresh':
          // The Quick Add refresh tap just opens the app and re-pushes the
          // latest snapshot to every widget; no navigation.
          _pushWidgets();
          break;
      }
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    // Providers outlive this screen; detach our listeners to avoid leaks. Use
    // the captured references, not context.read — the element is defunct during
    // dispose, so a lookup would throw.
    _expenseServiceRef?.removeListener(_pushWidgets);
    _accountServiceRef?.removeListener(_pushWidgets);
    _budgetServiceRef?.removeListener(_pushWidgets);
    super.dispose();
  }

  void _openQuickAdd() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.cardBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick add',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _quickAddTile(
                  sheetContext,
                  icon: Icons.receipt_long_rounded,
                  color: c.brand,
                  title: 'Add expense',
                  subtitle: 'Track personal spending',
                  builder: (_) => const AddExpenseScreen(),
                ),
                _quickAddTile(
                  sheetContext,
                  icon: Icons.call_split_rounded,
                  color: c.accent,
                  title: 'Split a bill',
                  subtitle: 'Share an expense with friends',
                  builder: (_) => const AddSplitScreen(),
                ),
                _quickAddTile(
                  sheetContext,
                  icon: Icons.group_add_rounded,
                  color: c.info,
                  title: 'Create group',
                  subtitle: 'Track shared group expenses',
                  builder: (_) => const CreateGroupScreen(),
                ),
                _quickAddTile(
                  sheetContext,
                  icon: Icons.auto_awesome_rounded,
                  color: c.warning,
                  title: 'Ask the assistant',
                  subtitle: 'Add expenses by voice or chat',
                  builder: (_) => const AiAssistantScreen(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickAddTile(
    BuildContext sheetContext, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required WidgetBuilder builder,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(sheetContext);
        Navigator.push(context, MaterialPageRoute(builder: builder));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      // Expenses/Splits/Groups each have their own contextual FAB, so the
      // quick-add FAB only appears on the Dashboard tab.
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                heroTag: 'home_quick_add_fab',
                onPressed: _openQuickAdd,
                tooltip: 'Quick add',
                child: const Icon(Icons.add_rounded, size: 28),
              )
              : null,
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          AppNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Home',
          ),
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Expenses',
          ),
          AppNavItem(
            icon: Icons.call_split_outlined,
            selectedIcon: Icons.call_split_rounded,
            label: 'Splits',
          ),
          AppNavItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            label: 'Groups',
          ),
          AppNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

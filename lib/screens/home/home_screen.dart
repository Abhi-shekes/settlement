import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import '../../services/expense_service.dart';
import '../../services/account_service.dart';
import '../../services/recurring_service.dart';
import '../../services/budget_service.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/home_widget_service.dart';
import 'dashboard_screen.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../splits/splits_screen.dart';
import '../groups/groups_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';
import '../ai/ai_assistant_screen.dart';

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
    const AnalyticsScreen(),
    const ProfileScreen(),
  ];

  StreamSubscription<Uri?>? _widgetClickSub;
  bool _widgetListenersAttached = false;

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
      final expenseService = context.read<ExpenseService>();
      final recurringService = context.read<RecurringService>();
      final budgetService = context.read<BudgetService>();
      final groupService = context.read<GroupService>();
      final uid = context.read<AuthService>().currentUser?.uid;

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
        expenseService.addListener(_pushWidgets);
        accountService.addListener(_pushWidgets);
        budgetService.addListener(_pushWidgets);
      }

      // Register this device for push notifications now that we're signed in.
      if (uid != null) NotificationService.instance.registerDevice(uid);
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
      }
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    if (_widgetListenersAttached) {
      // Providers outlive this screen; detach our listeners to avoid leaks.
      context.read<ExpenseService>().removeListener(_pushWidgets);
      context.read<AccountService>().removeListener(_pushWidgets);
      context.read<BudgetService>().removeListener(_pushWidgets);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF008080),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_split),
            label: 'Splits',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

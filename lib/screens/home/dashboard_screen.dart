import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/group_service.dart';
import '../../services/budget_service.dart';
import '../../services/invitation_service.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/money.dart';
import '../../widgets/section_header.dart';
import '../../widgets/action_card.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/budget_progress_card.dart';
import '../expenses/add_expense_screen.dart';
import '../splits/add_split_screen.dart';
import '../groups/create_group_screen.dart';
import '../budgets/budget_screen.dart';
import '../analytics/analytics_screen.dart';
import '../requests/requests_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Defer the initial load so services don't notifyListeners mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<ExpenseService>().loadUserExpenses(),
      context.read<GroupService>().loadUserGroups(),
      context.read<GroupService>().loadUserSplits(),
      context.read<BudgetService>().loadUserBudgets(),
      context.read<AuthService>().loadIncomingFriendRequests(),
      context.read<InvitationService>().loadReceivedInvitations(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: c.brand,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildBudgetAlerts(),
                  _buildQuickActions(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildRecentActivity(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero header: greeting + net-position summary ──────────────────────────

  SliverToBoxAdapter _buildHeader() {
    final c = context.colors;
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.heroGradientStart, c.heroGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadii.xl),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: AppSpacing.lg),
                _buildNetPosition(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final c = context.colors;
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final name = auth.currentUser?.displayName?.split(' ').first ?? 'there';
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      color: c.onBrand.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: AppTypography.money(fontSize: 24, color: c.onBrand),
                  ),
                ],
              ),
            ),
            _headerAction(
              icon: Icons.insights_rounded,
              tooltip: 'Analytics',
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Consumer3<AuthService, GroupService, InvitationService>(
              builder: (context, auth, groups, invites, _) {
                final count = pendingRequestCount(auth, groups, invites);
                return _headerAction(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Requests',
                  badgeCount: count,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RequestsScreen(),
                        ),
                      ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final c = context.colors;
    return Material(
      color: c.onBrand.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Tooltip(
            message: tooltip,
            child: CountBadge(
              count: badgeCount,
              child: Icon(icon, color: c.onBrand, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetPosition() {
    return Consumer2<ExpenseService, GroupService>(
      builder: (context, expenseService, groupService, _) {
        final c = context.colors;
        final uid = context.read<AuthService>().currentUser?.uid ?? '';
        final totalOwed = groupService.getTotalAmountOwed(uid); // you owe
        final totalOwing = groupService.getTotalAmountOwing(uid); // owed to you
        final net = totalOwing - totalOwed;
        final settled = net.abs() < 0.5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settled
                  ? "You're all settled up"
                  : net > 0
                  ? 'You are owed overall'
                  : 'You owe overall',
              style: TextStyle(
                color: c.onBrand.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              settled ? '₹0' : formatCurrency(net.abs()),
              style: AppTypography.money(fontSize: 40, color: c.onBrand),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _pillStat(
                    'Owed to you',
                    totalOwing,
                    Icons.south_west_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _pillStat(
                    'You owe',
                    totalOwed,
                    Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _pillStat(String label, double amount, IconData icon) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.onBrand.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.onBrand, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.onBrand.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                Text(
                  formatCurrency(amount, compact: true),
                  style: AppTypography.money(fontSize: 16, color: c.onBrand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Budget alerts ─────────────────────────────────────────────────────────

  Widget _buildBudgetAlerts() {
    return Consumer2<BudgetService, ExpenseService>(
      builder: (context, budgetService, expenseService, _) {
        final c = context.colors;
        final alertCategories =
            budgetService.getCategoriesWithBudgets().where((category) {
              final spending = expenseService.getTotalExpenseAmountByCategory(
                category,
              );
              final budget = budgetService.getBudgetForCategory(category);
              if (budget == null || budget.amount <= 0) return false;
              return spending >= budget.amount * 0.8;
            }).toList();

        if (alertCategories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Budget alerts',
              icon: Icons.warning_amber_rounded,
              iconColor: c.warning,
              actionLabel: 'Manage',
              onAction:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BudgetScreen()),
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...alertCategories.map((category) {
              final spending = expenseService.getTotalExpenseAmountByCategory(
                category,
              );
              final budget = budgetService.getBudgetForCategory(category);
              if (budget == null) return const SizedBox.shrink();
              return BudgetProgressCard(
                category: category,
                budgetAmount: budget.amount,
                currentSpending: spending,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BudgetScreen()),
                    ),
              );
            }),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final c = context.colors;
    final actions = [
      (
        'Add expense',
        'Track spending',
        Icons.add_card_rounded,
        c.brand,
        () => _push(const AddExpenseScreen()),
      ),
      (
        'Split bill',
        'Share with friends',
        Icons.call_split_rounded,
        c.accent,
        () => _push(const AddSplitScreen()),
      ),
      (
        'Create group',
        'Group expenses',
        Icons.group_add_rounded,
        c.info,
        () => _push(const CreateGroupScreen()),
      ),
      (
        'Set budgets',
        'Category limits',
        Icons.savings_rounded,
        c.positive,
        () => _push(const BudgetScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick actions'),
        const SizedBox(height: AppSpacing.sm),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 116,
          ),
          children: [
            for (final a in actions)
              ActionCard(
                title: a.$1,
                subtitle: a.$2,
                icon: a.$3,
                accent: a.$4,
                onTap: a.$5,
              ),
          ],
        ),
      ],
    );
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ── Recent activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Consumer2<ExpenseService, GroupService>(
      builder: (context, expenseService, groupService, _) {
        final c = context.colors;
        final uid = context.read<AuthService>().currentUser?.uid ?? '';
        final List<ActivityItem> activities = [];

        for (final expense in expenseService.expenses.take(4)) {
          activities.add(
            ActivityItem(
              type: ActivityType.personalExpense,
              title: expense.title,
              amount: expense.amount,
              date: expense.createdAt,
              icon: Icons.receipt_long_rounded,
              color: c.brand,
              subtitle: expense.categoryDisplayName,
            ),
          );
        }
        for (final split in groupService.splits.take(4)) {
          final isGroup = split.groupId != null;
          activities.add(
            ActivityItem(
              type:
                  isGroup
                      ? ActivityType.groupSplit
                      : ActivityType.individualSplit,
              title: split.title,
              amount: split.totalAmount,
              date: split.createdAt,
              icon: isGroup ? Icons.groups_rounded : Icons.call_split_rounded,
              color: isGroup ? c.info : c.accent,
              subtitle: split.paidBy == uid ? 'You paid' : 'Split expense',
            ),
          );
        }
        activities.sort((a, b) => b.date.compareTo(a.date));
        final display = activities.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Recent activity'),
            const SizedBox(height: AppSpacing.sm),
            if (display.isEmpty)
              EmptyState(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                message: 'Add an expense or split a bill to see it here.',
                actionLabel: 'Add expense',
                onAction: () => _push(const AddExpenseScreen()),
                compact: true,
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: AppRadii.card,
                  border: Border.all(color: c.cardBorder),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < display.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.cardBorder),
                      _buildActivityItem(display[i]),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    final theme = Theme.of(context);
    final c = context.colors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: activity.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Icon(activity.icon, color: activity.color, size: 22),
      ),
      title: Text(
        activity.title,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${activity.subtitle} · ${_formatDate(activity.date)}',
        style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatCurrency(activity.amount),
        style: AppTypography.money(fontSize: 15, color: activity.color),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

enum ActivityType { personalExpense, individualSplit, groupSplit }

class ActivityItem {
  final ActivityType type;
  final String title;
  final double amount;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String subtitle;

  ActivityItem({
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}

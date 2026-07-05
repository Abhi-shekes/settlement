import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/split_model.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import 'add_split_screen.dart';
import 'split_detail_screen.dart';
import '../requests/requests_screen.dart';

class SplitsScreen extends StatefulWidget {
  const SplitsScreen({super.key});

  @override
  State<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends State<SplitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSplits());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSplits() async {
    await context.read<GroupService>().loadUserSplits();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        title: const Text('Splits'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'You owe'),
            Tab(text: 'Owed to you'),
          ],
        ),
      ),
      body: Column(
        children: [
          _pendingBanner(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search splits',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSplitsList(SplitListType.youOwe),
                _buildSplitsList(SplitListType.owedToYou),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'splits_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddSplitScreen()),
          );
          _refreshSplits();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Split'),
      ),
    );
  }

  Widget _pendingBanner() {
    return Consumer2<GroupService, AuthService>(
      builder: (context, groups, auth, _) {
        final c = context.colors;
        final me = auth.currentUser?.uid ?? '';
        final approvals = groups.splitsAwaitingApprovalFrom(me).length;
        final confirms = groups.pendingSettlementsToConfirm(me).length;
        final total = approvals + confirms;
        if (total == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Material(
            color: c.accentSoft,
            borderRadius: AppRadii.card,
            child: InkWell(
              borderRadius: AppRadii.card,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestsScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.handshake_rounded, color: c.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '$total item${total == 1 ? '' : 's'} need your confirmation',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: c.accent,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.accent),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSplitsList(SplitListType type) {
    return Consumer2<GroupService, AuthService>(
      builder: (context, groupService, authService, child) {
        final c = context.colors;
        if (groupService.isLoading) return const SkeletonList();

        final currentUserId = authService.currentUser?.uid ?? '';
        List<SplitModel> splits;
        switch (type) {
          case SplitListType.all:
            splits = groupService.splits;
            break;
          case SplitListType.youOwe:
            splits = groupService.getUserOwedSplits(currentUserId);
            break;
          case SplitListType.owedToYou:
            splits = groupService.getUserOwingSplits(currentUserId);
            break;
        }

        if (_searchQuery.isNotEmpty) {
          splits = splits.where((split) {
            return split.title.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                split.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
        }

        if (splits.isEmpty) return _buildEmptyState(type);

        return RefreshIndicator(
          onRefresh: _refreshSplits,
          color: c.brand,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: splits.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) =>
                _buildSplitCard(splits[index], currentUserId),
          ),
        );
      },
    );
  }

  Widget _buildSplitCard(SplitModel split, String currentUserId) {
    final theme = Theme.of(context);
    final c = context.colors;
    final isGroupSplit = split.groupId != null;
    final isPayer = split.paidBy == currentUserId;

    double amount;
    String amountText;
    Color amountColor;

    if (isPayer) {
      amount = split.participants
          .where((p) => p != currentUserId)
          .fold(0.0, (sum, p) => sum + split.getRemainingAmount(p));
      amountText = amount > 0 ? '+₹${amount.toInt()}' : '₹0';
      amountColor = amount > 0 ? c.positive : c.faint;
    } else {
      amount = split.getRemainingAmount(currentUserId);
      amountText = amount > 0 ? '-₹${amount.toInt()}' : '₹0';
      amountColor = amount > 0 ? c.negative : c.faint;
    }

    final iconColor = isGroupSplit ? c.info : c.accent;

    return Material(
      color: c.surfaceElevated,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SplitDetailScreen(split: split),
            ),
          ).then((_) => _refreshSplits());
        },
        borderRadius: AppRadii.card,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadii.card,
            border: Border.all(color: c.cardBorder),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  isGroupSplit ? Icons.groups_rounded : Icons.person_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      split.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      split.description.isEmpty
                          ? (isPayer ? 'You paid' : 'You owe')
                          : split.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total ${split.formattedTotalAmount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: c.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: AppTypography.money(fontSize: 15, color: amountColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d').format(split.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: c.faint),
                  ),
                  const SizedBox(height: 6),
                  AppChip(
                    label: split.isFullySettled ? 'Settled' : 'Pending',
                    color: split.isFullySettled ? c.positive : c.warning,
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(SplitListType type) {
    String title;
    String message;
    IconData icon;

    switch (type) {
      case SplitListType.all:
        title = 'No splits yet';
        message = _searchQuery.isNotEmpty
            ? 'Try a different search.'
            : 'Split a bill with friends to get started.';
        icon = Icons.call_split_rounded;
        break;
      case SplitListType.youOwe:
        title = "You're all clear";
        message = _searchQuery.isNotEmpty
            ? 'Try a different search.'
            : "You don't owe anyone right now.";
        icon = Icons.check_circle_rounded;
        break;
      case SplitListType.owedToYou:
        title = 'Nothing owed to you';
        message = _searchQuery.isNotEmpty
            ? 'Try a different search.'
            : 'Everyone has settled up with you.';
        icon = Icons.account_balance_wallet_rounded;
        break;
    }

    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: (_searchQuery.isEmpty && type == SplitListType.all)
          ? 'Split a bill'
          : null,
      onAction: (_searchQuery.isEmpty && type == SplitListType.all)
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSplitScreen()),
              )
          : null,
    );
  }
}

enum SplitListType { all, youOwe, owedToYou }

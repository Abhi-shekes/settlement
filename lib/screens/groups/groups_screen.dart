import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshGroups());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshGroups() async {
    await context.read<GroupService>().loadUserGroups();
  }

  List<GroupModel> _getFilteredGroups() {
    final groupService = context.watch<GroupService>();
    List<GroupModel> filteredGroups = List.from(groupService.groups);

    if (_searchQuery.isNotEmpty) {
      filteredGroups = filteredGroups.where((group) {
        return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            group.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    filteredGroups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filteredGroups;
  }

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _getFilteredGroups();
    final groupService = context.watch<GroupService>();
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(title: const Text('Groups')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search groups',
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
            child: groupService.isLoading
                ? const SkeletonList()
                : filteredGroups.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshGroups,
                    color: c.brand,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filteredGroups.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) =>
                          _buildGroupCard(filteredGroups[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'groups_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          );
          _refreshGroups();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New group'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.groups_rounded,
      title: _searchQuery.isNotEmpty ? 'No groups found' : 'No groups yet',
      message: _searchQuery.isNotEmpty
          ? 'Try a different search.'
          : 'Create a group to split expenses with friends and roommates.',
      actionLabel: _searchQuery.isEmpty ? 'Create group' : null,
      onAction: _searchQuery.isEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              )
          : null,
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    final theme = Theme.of(context);
    final c = context.colors;
    final currentUserId = context.read<AuthService>().currentUser?.uid ?? '';
    final isAdmin = group.adminId == currentUserId;
    final memberCount = group.allMemberIds.length;

    return Material(
      color: c.surfaceElevated,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(group: group),
            ),
          ).then((_) => _refreshGroups());
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: c.info.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: group.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: Image.network(
                          group.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.groups_rounded, color: c.info, size: 28),
                        ),
                      )
                    : Icon(Icons.groups_rounded, color: c.info, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin)
                          AppChip(label: 'Admin', dense: true),
                      ],
                    ),
                    if (group.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        group.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 15, color: c.faint),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount member${memberCount != 1 ? 's' : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.faint,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Icon(Icons.schedule_rounded, size: 15, color: c.faint),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(group.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.faint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

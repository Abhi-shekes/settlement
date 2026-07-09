import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_notification.dart';
import '../../services/notification_center_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/notification_router.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';

/// The notification centre: full history with unread state, tap-to-open
/// deep-linking, swipe-to-dismiss, and bulk actions.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationCenterService>(
      builder: (context, center, _) {
        final items = center.items;
        final hasUnread = center.unreadCount > 0;
        return AppScaffold(
          title: 'Notifications',
          actions: [
            if (hasUnread)
              TextButton(
                onPressed: center.markAllRead,
                child: const Text('Mark all read'),
              ),
            if (items.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'clear') _confirmClear(context, center);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'clear', child: Text('Clear all')),
                ],
              ),
          ],
          body: items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      "Friend requests, split approvals, payments and group "
                      "activity will show up here.",
                )
              : _buildList(context, center, items),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    NotificationCenterService center,
    List<AppNotification> items,
  ) {
    // Group by calendar day, preserving the newest-first order.
    final groups = <String, List<AppNotification>>{};
    for (final n in items) {
      groups.putIfAbsent(_dayLabel(n.createdAt), () => []).add(n);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final n in entry.value) _tile(context, center, n),
        ],
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    NotificationCenterService center,
    AppNotification n,
  ) {
    final c = context.colors;
    final accent = n.color(c);
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.negativeSoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(Icons.delete_outline_rounded, color: c.negative),
      ),
      onDismissed: (_) => center.delete(n.id),
      child: Material(
        color: n.read ? Colors.transparent : accent.withValues(alpha: 0.06),
        child: InkWell(
          onTap: () {
            center.markRead(n.id);
            NotificationRouter.handle(n.data);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(n.icon, color: accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              n.read ? FontWeight.w600 : FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        style: TextStyle(color: c.muted, fontSize: 13, height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('h:mm a').format(n.createdAt),
                        style: TextStyle(color: c.faint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!n.read)
                  Container(
                    margin: const EdgeInsets.only(top: 6, left: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, NotificationCenterService center) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This removes your entire notification history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              center.clearAll();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final day = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('d MMM yyyy').format(dt);
  }
}

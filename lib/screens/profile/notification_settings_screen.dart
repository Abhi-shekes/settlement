import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../services/notification_center_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';

/// Per-category push preferences plus a master switch. History is always kept;
/// these toggles only gate the OS push (the Cloud Functions backend reads the
/// same `notificationPrefs` map before sending).
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Consumer<NotificationCenterService>(
      builder: (context, center, _) {
        final prefs = center.prefs;
        return AppScaffold(
          title: 'Notifications',
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: prefs.master,
                  onChanged: (v) =>
                      center.updatePrefs(prefs.copyWith(master: v)),
                  title: const Text(
                    'Push notifications',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Turn all push notifications on or off',
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  'CATEGORIES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < NotificationCategory.all.length; i++)
                      _categoryTile(
                        context,
                        center,
                        NotificationCategory.all[i],
                        last: i == NotificationCategory.all.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your notification history is always kept. These toggles only '
                'control the alerts pushed to this device.',
                style: TextStyle(color: c.faint, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryTile(
    BuildContext context,
    NotificationCenterService center,
    String category, {
    required bool last,
  }) {
    final c = context.colors;
    final prefs = center.prefs;
    final accent = NotificationCategory.color(c, category);
    final enabled = prefs.master && (prefs.categories[category] ?? true);
    return Column(
      children: [
        SwitchListTile(
          value: enabled,
          onChanged: prefs.master
              ? (v) => center.updatePrefs(prefs.withCategory(category, v))
              : null,
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(NotificationCategory.icon(category), color: accent, size: 18),
          ),
          title: Text(
            NotificationCategory.label(category),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          subtitle: Text(
            NotificationCategory.describe(category),
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
        ),
        if (!last)
          Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: c.cardBorder),
      ],
    );
  }
}

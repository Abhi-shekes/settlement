import 'app_notification.dart';

/// A user's push-notification preferences, persisted on their user document at
/// `users/{uid}.notificationPrefs`. Everything defaults to ON so a user who has
/// never opened the settings screen still receives notifications; the Cloud
/// Functions backend reads the same map to decide whether to push.
///
/// History is always retained regardless of these toggles — they only gate the
/// OS push.
class NotificationPreferences {
  /// Master kill-switch. When off, no pushes are sent for any category.
  final bool master;

  /// Per-category enablement, keyed by [NotificationCategory] constants.
  final Map<String, bool> categories;

  const NotificationPreferences({
    this.master = true,
    this.categories = const {},
  });

  /// All categories enabled — the default for a brand-new user.
  factory NotificationPreferences.defaults() => const NotificationPreferences();

  bool isEnabled(String category) {
    if (!master) return false;
    return categories[category] ?? true;
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return NotificationPreferences.defaults();
    final cats = <String, bool>{};
    for (final c in NotificationCategory.all) {
      if (map[c] is bool) cats[c] = map[c] as bool;
    }
    return NotificationPreferences(
      master: (map['master'] ?? true) as bool,
      categories: cats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'master': master,
      for (final c in NotificationCategory.all) c: isEnabled(c),
    };
  }

  NotificationPreferences copyWith({
    bool? master,
    Map<String, bool>? categories,
  }) {
    return NotificationPreferences(
      master: master ?? this.master,
      categories: categories ?? this.categories,
    );
  }

  NotificationPreferences withCategory(String category, bool value) {
    return copyWith(categories: {...categories, category: value});
  }
}

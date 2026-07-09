import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Notification categories. These line up 1:1 with the Cloud Functions
/// `Category` map, the per-category Android channels, and the preference
/// toggles in the notification-settings screen.
class NotificationCategory {
  static const String requests = 'requests';
  static const String payments = 'payments';
  static const String groups = 'groups';
  static const String budgets = 'budgets';
  static const String system = 'system';

  static const List<String> all = [requests, payments, groups, budgets, system];

  /// Human label for a category, used in the settings screen.
  static String label(String category) {
    switch (category) {
      case requests:
        return 'Requests & approvals';
      case payments:
        return 'Payments';
      case groups:
        return 'Groups';
      case budgets:
        return 'Budget alerts';
      default:
        return 'General';
    }
  }

  static String describe(String category) {
    switch (category) {
      case requests:
        return 'Friend requests, split-share approvals';
      case payments:
        return 'Payment confirmations and settlements';
      case groups:
        return 'Group invites, expenses and new members';
      case budgets:
        return 'When you approach or exceed a budget';
      default:
        return 'App updates and everything else';
    }
  }

  static IconData icon(String category) {
    switch (category) {
      case requests:
        return Icons.person_add_alt_1_rounded;
      case payments:
        return Icons.payments_rounded;
      case groups:
        return Icons.groups_rounded;
      case budgets:
        return Icons.savings_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// The accent color for a category, taken from the design-system tokens so it
  /// stays correct in light and dark mode.
  static Color color(AppColors c, String category) {
    switch (category) {
      case requests:
        return c.info;
      case payments:
        return c.positive;
      case groups:
        return c.accent;
      case budgets:
        return c.warning;
      default:
        return c.brand;
    }
  }
}

/// One entry in a user's notification history
/// (`users/{uid}/notifications/{id}`). Written by Cloud Functions (server
/// events) and by the client for local budget alerts.
class AppNotification {
  final String id;
  final String type;
  final String category;
  final String title;
  final String body;
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  IconData get icon => NotificationCategory.icon(category);
  Color color(AppColors c) => NotificationCategory.color(c, category);

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const {};
    final rawData = (map['data'] as Map?) ?? const {};
    return AppNotification(
      id: doc.id,
      type: (map['type'] ?? '') as String,
      category: (map['category'] ?? NotificationCategory.system) as String,
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      data: rawData.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      read: (map['read'] ?? false) as bool,
      // serverTimestamp() is momentarily null between the local write and the
      // server round-trip; fall back to "now" so the row still renders.
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Shape used when the client writes a notification directly (budget alerts).
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'category': category,
      'title': title,
      'body': body,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

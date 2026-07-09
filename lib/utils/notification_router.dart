import 'package:flutter/material.dart';
import '../screens/requests/requests_screen.dart';
import '../screens/splits/splits_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/budgets/budget_screen.dart';
import '../screens/invitations/invitations_screen.dart';
import '../screens/notifications/notifications_screen.dart';

/// Maps a notification's `data` payload to an in-app destination. Shared by the
/// FCM tap handlers (foreground open, background open, cold start) and the
/// local-notification tap callback, so every path deep-links the same way.
class NotificationRouter {
  NotificationRouter._();

  /// Set by `main.dart` and handed to `MaterialApp.navigatorKey`, so we can
  /// navigate from outside the widget tree (e.g. an FCM callback).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Routes based on the notification `type`. Unknown types fall back to the
  /// in-app notification centre so the tap is never a dead end.
  static void handle(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final type = (data['type'] ?? '').toString();

    WidgetPageBuilder? builder;
    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
      case 'split_approval':
      case 'split_share_accepted':
      case 'split_share_declined':
      case 'settlement_confirm':
        builder = (_) => const RequestsScreen();
        break;
      case 'settlement_confirmed':
      case 'settlement_rejected':
      case 'split_settled':
        builder = (_) => const SplitsScreen();
        break;
      case 'group_invite':
        builder = (_) => const InvitationsScreen();
        break;
      case 'group_expense':
      case 'group_member':
        builder = (_) => const GroupsScreen();
        break;
      case 'budget':
        builder = (_) => const BudgetScreen();
        break;
      default:
        builder = (_) => const NotificationsScreen();
    }

    nav.push(MaterialPageRoute(builder: builder));
  }
}

typedef WidgetPageBuilder = Widget Function(BuildContext);

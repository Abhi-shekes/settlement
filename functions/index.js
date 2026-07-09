/**
 * Cloud Functions are intentionally DISABLED for the Settlement app.
 *
 * The project runs on the Firebase **Spark (free)** plan, which does not allow
 * Cloud Functions (they require the Blaze pay-as-you-go plan). Notifications are
 * therefore generated entirely on the client: whichever app performs an action
 * writes the notification straight into the recipient's
 * `users/{uid}/notifications` subcollection, and each recipient's app raises a
 * local heads-up via a Firestore listener. See:
 *   - lib/services/notification_emitter.dart   (writes to recipients)
 *   - lib/services/notification_center_service.dart (streams + local heads-up)
 *
 * There are no exported functions here, so `firebase deploy` will not attempt to
 * deploy anything and no Blaze upgrade is needed.
 *
 * ── If you later upgrade to Blaze and want true server push (delivery even when
 * the recipient's app is terminated) ──
 * Restore the trigger-based implementation from git history (the commit that
 * introduced this file) and, to avoid duplicate notifications, remove the
 * `NotificationEmitter` calls from the client services (auth_service,
 * group_service, invitation_service) and the budget alert in add_expense_screen.
 * The client `NotificationCenterService` / notification centre UI stay as-is.
 */

// No exports — nothing is deployed.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes notifications into other users' history from the acting client.
///
/// The app runs on the Firebase **Spark (free)** plan, which has no Cloud
/// Functions, so there is no server to fan events out. Instead, whichever client
/// performs an action records the resulting notification directly in the
/// recipient's `users/{uid}/notifications` subcollection. Each recipient's app
/// streams that subcollection (see `NotificationCenterService`) and raises a
/// local heads-up when a new one arrives while it is running.
///
/// History is always written here; whether a local heads-up is shown is decided
/// on the recipient's device from their own preferences.
class NotificationEmitter {
  NotificationEmitter._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Records a notification for [uid]. Fire-and-forget: failures are logged but
  /// never block the primary action that triggered them.
  static Future<void> send(
    String uid, {
    required String type,
    required String category,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
            'type': type,
            'category': category,
            'title': title,
            'body': body,
            'data': {...data, 'type': type, 'category': category},
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('NotificationEmitter.send($uid) failed: $e');
    }
  }

  /// Sends to every uid in [uids] (skipping empties/duplicates).
  static Future<void> sendToAll(
    Iterable<String> uids, {
    required String type,
    required String category,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    final targets = uids.where((u) => u.isNotEmpty).toSet();
    await Future.wait(
      targets.map(
        (u) => send(
          u,
          type: type,
          category: category,
          title: title,
          body: body,
          data: data,
        ),
      ),
    );
  }

  /// Resolves an email to a user id (if that person has an account) and sends.
  /// Used for group invitations, which are addressed by email.
  static Future<void> sendToEmail(
    String email, {
    required String type,
    required String category,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    if (email.isEmpty) return;
    try {
      final q = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) return; // invitee hasn't signed up yet
      await send(
        q.docs.first.id,
        type: type,
        category: category,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('NotificationEmitter.sendToEmail($email) failed: $e');
    }
  }
}

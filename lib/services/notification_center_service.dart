import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import '../models/notification_prefs.dart';
import 'notification_service.dart';

/// Owns the in-app notification centre: a live stream of the signed-in user's
/// notification history (`users/{uid}/notifications`), the unread count that
/// drives the dashboard bell badge, and the user's push preferences.
///
/// Server events are written by Cloud Functions; the client also writes local
/// budget alerts here via [addLocal] so they appear in the same history.
class NotificationCenterService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _limit = 100;

  String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// The first snapshot loads existing history; only notifications that arrive
  /// *after* it should raise a heads-up (otherwise every launch would re-alert).
  bool _primed = false;

  List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  NotificationPreferences _prefs = NotificationPreferences.defaults();
  NotificationPreferences get prefs => _prefs;

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  /// Begin streaming notifications for [uid]. Safe to call repeatedly; a no-op
  /// if already bound to the same user.
  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _primed = false;
    _sub = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(_limit)
        .snapshots()
        .listen((snap) {
          _items = snap.docs.map(AppNotification.fromDoc).toList();
          _raiseHeadsUpFor(snap);
          _primed = true;
          notifyListeners();
        }, onError: (e) => debugPrint('notifications stream error: $e'));
    loadPrefs();
  }

  /// Shows a local heads-up for notifications that were *added* since the last
  /// snapshot (skipping the initial load and local metadata-only echoes), so
  /// the recipient is alerted even though there is no server push. Gated by the
  /// recipient's own category preferences.
  void _raiseHeadsUpFor(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!_primed) return;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      // Skip the optimistic local echo of a write this device just made; the
      // server-confirmed copy (pending == false) is the one we alert on, so
      // each notification raises exactly one heads-up.
      if (change.doc.metadata.hasPendingWrites) continue;
      final n = AppNotification.fromDoc(change.doc);
      if (n.read) continue;
      if (!_prefs.isEnabled(n.category)) continue;
      NotificationService.instance.showLocal(
        title: n.title,
        body: n.body,
        category: n.category,
        data: {...n.data, 'type': n.type},
      );
    }
  }

  /// Detach from the current user (sign-out). Clears cached state.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _items = [];
    _prefs = NotificationPreferences.defaults();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final col = _collection;
    if (col == null) return;
    // Optimistic local update so the badge responds instantly.
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0 && !_items[i].read) {
      _items[i] = _copyRead(_items[i], true);
      notifyListeners();
    }
    try {
      await col.doc(id).update({'read': true});
    } catch (e) {
      debugPrint('markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    final col = _collection;
    if (col == null) return;
    final unread = _items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    _items = _items.map((n) => n.read ? n : _copyRead(n, true)).toList();
    notifyListeners();
    try {
      final batch = _firestore.batch();
      for (final n in unread) {
        batch.update(col.doc(n.id), {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markAllRead failed: $e');
    }
  }

  Future<void> delete(String id) async {
    final col = _collection;
    if (col == null) return;
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
    try {
      await col.doc(id).delete();
    } catch (e) {
      debugPrint('delete notification failed: $e');
    }
  }

  Future<void> clearAll() async {
    final col = _collection;
    if (col == null) return;
    final ids = _items.map((n) => n.id).toList();
    _items = [];
    notifyListeners();
    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(col.doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('clearAll failed: $e');
    }
  }

  /// Records a client-generated notification (budget alerts). The stream will
  /// pick it up, so we don't touch [_items] directly.
  Future<void> addLocal(AppNotification n) async {
    final col = _collection;
    if (col == null) return;
    try {
      await col.add(n.toMap());
    } catch (e) {
      debugPrint('addLocal notification failed: $e');
    }
  }

  // --- Preferences -----------------------------------------------------------

  Future<void> loadPrefs() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      _prefs = NotificationPreferences.fromMap(
        doc.data()?['notificationPrefs'] as Map<String, dynamic>?,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('loadPrefs failed: $e');
    }
  }

  Future<void> updatePrefs(NotificationPreferences prefs) async {
    final uid = _uid;
    if (uid == null) return;
    _prefs = prefs;
    notifyListeners();
    try {
      await _firestore.collection('users').doc(uid).update({
        'notificationPrefs': prefs.toMap(),
      });
    } catch (e) {
      debugPrint('updatePrefs failed: $e');
    }
  }

  AppNotification _copyRead(AppNotification n, bool read) {
    return AppNotification(
      id: n.id,
      type: n.type,
      category: n.category,
      title: n.title,
      body: n.body,
      data: n.data,
      read: read,
      createdAt: n.createdAt,
    );
  }
}

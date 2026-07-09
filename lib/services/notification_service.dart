import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import '../utils/notification_router.dart';

/// Background/terminated message handler. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS renders the "notification" payload itself while the app is in the
  // background, so there is nothing to draw here. Taps are handled by
  // onMessageOpenedApp / getInitialMessage once the app resumes.
}

/// Device-side notification layer. Wires up FCM (permission, tokens, foreground
/// display, tap routing) and drives the local-notification plugin used both for
/// foreground pushes and for client-generated alerts (e.g. budgets).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// One Android channel per notification category so users can tune each
  /// category in the OS settings and each gets an appropriate importance.
  static const Map<String, String> _channelNames = {
    NotificationCategory.requests: 'Requests & approvals',
    NotificationCategory.payments: 'Payments',
    NotificationCategory.groups: 'Groups',
    NotificationCategory.budgets: 'Budget alerts',
    NotificationCategory.system: 'General',
  };

  bool _initialised = false;

  /// Cold-start message captured before the navigator exists; routed once the
  /// app is ready via [routePendingInitialMessage].
  Map<String, dynamic>? _pendingInitial;

  /// One-time setup: permission, channels, foreground/tap listeners. Call after
  /// Firebase is initialised and before runApp.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _messaging.requestPermission();

    // Show heads-up banners for foreground messages on iOS too (Android draws
    // them via the local-notification plugin below).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );
    await _createChannels();

    // Foreground: FCM does not draw a banner itself, so we render one locally.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Background → tap opened the app.
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      NotificationRouter.handle(_asStringMap(m.data));
    });

    // Terminated → tap that cold-started the app. Stashed until the UI exists.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _pendingInitial = _asStringMap(initial.data);

    _messaging.onTokenRefresh.listen((token) {
      final uid = _currentUidGetter?.call();
      if (uid != null) _saveToken(uid, token);
    });
  }

  Future<void> _createChannels() async {
    final android =
        _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) return;
    for (final entry in _channelNames.entries) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          entry.key,
          entry.value,
          importance: Importance.high,
        ),
      );
    }
  }

  /// Routes a cold-start notification tap once the navigator is available.
  /// Call from the first authenticated screen after the initial frame.
  void routePendingInitialMessage() {
    final data = _pendingInitial;
    _pendingInitial = null;
    if (data != null) NotificationRouter.handle(data);
  }

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      NotificationRouter.handle(data);
    } catch (_) {
      /* malformed payload — ignore */
    }
  }

  void _showForeground(RemoteMessage message) {
    final data = _asStringMap(message.data);
    final n = message.notification;
    // Fall back to the data payload for data-only messages so they still show.
    final title = n?.title ?? data['title']?.toString();
    final body = n?.body ?? data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    final category =
        (data['category'] ?? NotificationCategory.system).toString();
    showLocal(
      title: title ?? '',
      body: body ?? '',
      category: category,
      data: data,
    );
  }

  /// Displays a local notification. Used for foreground FCM messages and for
  /// client-generated alerts (budgets). [data] is carried in the tap payload so
  /// the tap deep-links just like a server push.
  Future<void> showLocal({
    required String title,
    required String body,
    String category = NotificationCategory.system,
    Map<String, dynamic> data = const {},
  }) async {
    final channelId =
        _channelNames.containsKey(category)
            ? category
            : NotificationCategory.system;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelNames[channelId]!,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({...data, if (!data.containsKey('type')) 'type': ''}),
    );
  }

  // Lets the service fetch the current user id without importing AuthService.
  String? Function()? _currentUidGetter;
  set currentUidGetter(String? Function() getter) => _currentUidGetter = getter;

  /// Registers this device's token against [uid]. Call once the user is signed
  /// in (a user may have several devices, so tokens are stored as an array).
  Future<void> registerDevice(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  /// Removes this device's token from [uid] (call on sign-out so a shared
  /// device stops receiving the previous user's notifications).
  Future<void> unregisterDevice(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Map<String, dynamic> _asStringMap(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}

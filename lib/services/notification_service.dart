import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background/terminated message handler. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS renders the "notification" payload itself while the app is in the
  // background, so there is nothing to do here for display. Kept as a hook.
}

/// Wires up Firebase Cloud Messaging on the device: asks for permission, keeps
/// the user's FCM tokens in their Firestore doc (so the Cloud Functions backend
/// can target them), and shows a local notification for foreground messages.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'settlement_default',
    'Settlement notifications',
    description: 'Friend requests, split approvals, payments and invites',
    importance: Importance.high,
  );

  bool _initialised = false;

  /// One-time setup: permission, local-notification channel, foreground and
  /// token-refresh listeners. Call after Firebase is initialised.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _messaging.requestPermission();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Show a heads-up notification while the app is in the foreground (FCM does
    // not draw one itself in that state).
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    _messaging.onTokenRefresh.listen((token) {
      final uid = _currentUidGetter?.call();
      if (uid != null) _saveToken(uid, token);
    });
  }

  // Lets the service fetch the current user id without importing AuthService.
  String? Function()? _currentUidGetter;
  set currentUidGetter(String? Function() getter) =>
      _currentUidGetter = getter;

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
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}

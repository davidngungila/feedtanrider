import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config.dart';
import '../screens/order_detail_screen.dart';
import '../state/session_expired.dart';
import 'api_service.dart';

/// Runs in a separate isolate when the app is backgrounded or terminated,
/// so data-only FCM messages can still surface a notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushService.instance.initForBackground();
  await PushService.instance.showLocalNotification(message);
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSub;
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Deliveries & Alerts',
    description: 'New delivery requests, order updates and account alerts.',
    importance: Importance.high,
  );

  /// Full initialization from the UI isolate (called from main()).
  Future<void> init() async {
    if (!AppConfig.firebaseEnabled) return;
    await Firebase.initializeApp();
    await _setupLocalNotifications();

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ runtime notification permission.
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    FirebaseMessaging.onMessage.listen(showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(handleOpenedApp);

    // App launched by tapping a notification while it was terminated.
    final initial = await messaging.getInitialMessage();
    if (initial != null) handleOpenedApp(initial);

    _ready = true;
  }

  /// Minimal initialization for the background isolate.
  Future<void> initForBackground() async {
    if (!AppConfig.firebaseEnabled) return;
    await Firebase.initializeApp();
    await _setupLocalNotifications();
    _ready = true;
  }

  Future<void> _setupLocalNotifications() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _navigateToPayload(response.payload),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Sends the FCM token to the backend (called after login/bootstrap).
  Future<void> registerToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.instance.updateDeviceToken(token);
      }
      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => ApiService.instance.updateDeviceToken(t));
    } catch (_) {
      // Offline or not ready — retried on next login / token refresh.
    }
  }

  /// Displays a local notification (foreground messages, or data-only
  /// messages handled from the background isolate).
  Future<void> showLocalNotification(RemoteMessage message) async {
    if (!_ready) return;
    final notification = message.notification;
    final title = notification?.title ?? 'Feedtan Rider';
    final body =
        notification?.body ?? message.data['body'] ?? 'You have a new update';
    await _notifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Deliveries & Alerts',
          channelDescription: 'New delivery requests, order updates and account alerts.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: _payloadFor(message),
    );
  }

  void handleOpenedApp(RemoteMessage message) {
    _navigateToPayload(_payloadFor(message));
  }

  String _payloadFor(RemoteMessage message) {
    final data = message.data;
    final type =
        data['type'] ?? data['event'] ?? message.notification?.title ?? '';
    final orderId = data['order_id'] ??
        data['dispatch_request_id'] ??
        data['orderId'] ??
        data['id'] ??
        '';
    return '$type|$orderId';
  }

  void _navigateToPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    final orderId = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (orderId == null) return;
    final nav = ApiSessionExpiredBinder.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => OrderDetailScreen(orderId: orderId),
    ));
  }
}

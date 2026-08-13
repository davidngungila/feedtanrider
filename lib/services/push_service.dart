import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config.dart';
import '../models.dart';
import '../screens/order_detail_screen.dart';
import '../state/session_expired.dart';
import '../state/tabs.dart';
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

  /// Consumed by [MainShell.initState] when the app is launched from a
  /// terminated state by tapping a notification.
  static int? pendingInitialTab;
  static int? pendingInitialOrderId;

  /// Applies a cold-start notification intent once the shell is up.
  static void consumeInitialIntent() {
    final tab = pendingInitialTab;
    final orderId = pendingInitialOrderId;
    pendingInitialTab = null;
    pendingInitialOrderId = null;
    shellTab.value = tab ?? 0;
    if (orderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ApiSessionExpiredBinder.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderId),
          ),
        );
      });
    }
  }

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSub;
  bool _ready = false;

  /// Matches the backend `FCM_DEFAULT_CHANNEL` so system-posted
  /// notification messages (background/terminated state) display correctly.
  static const _channel = AndroidNotificationChannel(
    'general',
    'General notifications',
    description: 'Order, trip and dispatch updates.',
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

  /// Tells the backend to deactivate this device's token on logout.
  Future<void> unregisterToken() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.instance.removeDeviceToken(token);
      }
    } catch (_) {
      // Best-effort cleanup; the server row expires/becomes stale anyway.
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
          'general',
          'General notifications',
          channelDescription: 'Order, trip and dispatch updates.',
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

  /// Shows a local push notification when a new available delivery request is
  /// detected by the polling loop. Tapping it opens the Available tab.
  /// Deliberately omits product prices and the delivery address.
  Future<void> notifyDispatchRequest(DispatchRequest r) async {
    if (!_ready) return;
    final order = r.order;
    final title = 'New delivery request';
    final items = order.items
        .map((it) => '${it.quantity} × ${it.productName}')
        .take(3)
        .join(', ');
    final itemInfo = items.isEmpty
        ? '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}'
        : items;
    final payment = order.isCash
        ? 'Collect cash on delivery'
        : (order.paymentMethod ?? 'Paid online');
    final body = order.orderNumber.isNotEmpty
        ? 'Order ${order.orderNumber} · ${order.customerName}\n$itemInfo · $payment'
        : 'A new delivery is available near you';
    await _notifications.show(
      id: r.id.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'General notifications',
          channelDescription: 'Order, trip and dispatch updates.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'dispatch.request.new|${order.id}',
    );
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
    final nav = ApiSessionExpiredBinder.navigatorKey.currentState;

    final type = (parts.isNotEmpty ? parts.first : '').toUpperCase();
    final orderId = parts.length > 1 ? int.tryParse(parts[1]) : null;

    // "New delivery available" style alerts open the Available tab so the
    // rider can Accept/Decline the request right away.
    final isDispatch = type.contains('DISPATCH') ||
        type.contains('TRIP') ||
        type.contains('AVAILABLE') ||
        type.contains('NEW_ORDER') ||
        type.contains('REQUEST');
    if (isDispatch) {
      if (nav == null) {
        pendingInitialTab = 1;
      } else {
        shellTab.value = 1;
      }
      return;
    }
    if (orderId == null) return;
    if (nav != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: orderId),
      ));
    } else {
      pendingInitialOrderId = orderId;
    }
  }
}

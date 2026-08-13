# FeedTan Store — Push Notifications (Mobile App Implementation Guide)

Implementation guide for the **Flutter rider app** (`com.feedtanstore.rider`)
receiving push notifications from the FeedTan Store backend via **Firebase Cloud
Messaging (FCM)**.

The backend is fully implemented and deployed (`FCM_ENABLED=true`,
`FCM_PROJECT_ID=feedtanstore-50473`). This guide covers everything the mobile
app needs: Firebase config, token registration, notification display, and
tap deep-linking.

Companion docs: `MOBILE_APP_NOTES.md`, `RIDER_MOBILE_APP_GUIDE.md`.

---

## 1. Architecture

```
                    FCM device token
Flutter Rider App  ---------------->  POST /api/device-token   (Laravel backend)
      |  ^                                 |   user_devices table
      |  |  APNs / FCM push                v
      v  |                             NotificationService  ->  FCM HTTP v1
  firebase_messaging                 (FcmClient, service-account OAuth2)
```

- The **app** registers its FCM token after login and refreshes it whenever
  Firebase issues a new one.
- The **backend** stores the token against the rider's user record and sends
  push messages for order/trip/dispatch/payment/message events.
- The **app** shows a local notification and deep-links on tap based on the
  payload (`type` + `screen`).

---

## 2. Prerequisites

- Firebase project: **feedtanstore-50473** (project number `267813656499`).
- Android app registered in Firebase with package **`com.feedtanstore.rider`**.
- Flutter packages: `firebase_core`, `firebase_messaging`,
  `flutter_local_notifications`, `firebase_messaging` (Android uses
  `firebase_messaging` for background delivery too).

```bash
flutter pub add firebase_core firebase_messaging flutter_local_notifications
```

---

## 3. Firebase config file

Place the **`google-services.json`** (the Android config file) at:

```
android/app/google-services.json
```

Your file must contain the rider app entry:

```json
{
  "project_info": {
    "project_number": "267813656499",
    "project_id": "feedtanstore-50473",
    "storage_bucket": "feedtanstore-50473.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:267813656499:android:3dd9ab5e0b5b2b413f9dc6",
        "android_client_info": { "package_name": "com.feedtanstore.rider" }
      }
    }
  ]
}
```

> This file is for the **mobile app only**. The backend uses a separate
> Firebase **service-account** key — never ship that file inside the app.

---

## 4. Android configuration

### 4.1 `android/build.gradle` (project-level) — add the Google services plugin

```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.4.2'
  }
}
```

### 4.2 `android/app/build.gradle` (app-level) — apply the plugin

```gradle
apply plugin: 'com.google.gms.google-services'
```

> Run once to refresh plugin resolution:
> `flutter clean && flutter pub get`

### 4.3 Notification permission (Android 13+)

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.INTERNET" />
```

Request the permission at runtime (Android 13+ shows a dialog; below 13 it is
granted automatically):

```dart
Future<void> requestNotificationPermission() async {
  if (Theme.of(context).platform == TargetPlatform.android) {
    final api = await DeviceInfoPlugin().androidInfo;
    if (api.version.sdkInt >= 33) {
      await Permission.notification.request();
    }
  }
}
```

(Or use the `permission_handler` package: `Permission.notification.request()`.)

### 4.4 Create the notification channel

The backend sends with `channel_id: general` by default
(`FCM_DEFAULT_CHANNEL=general`). Create that channel on app start:

```dart
final plugin = FlutterLocalNotificationsPlugin();
await plugin.initialize(
  const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  onDidReceiveNotificationResponse: handleTap,
);
await plugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(const AndroidNotificationChannel(
      'general',                  // must match FCM_DEFAULT_CHANNEL
      'General notifications',
      description: 'Order, trip and dispatch updates',
      importance: Importance.high,
    ));
```

> Android 8+ requires a channel with `high` importance for heads-up display.

---

## 5. Firebase init + FCM setup

`lib/services/push_service.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class PushService {
  static final PushService instance = PushService._();
  PushService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await Firebase.initializeApp();

    // Android 13+ runtime permission.
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Create the "general" channel (matches backend FCM_DEFAULT_CHANNEL).
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => handlePayload(r.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'general', 'General notifications',
          description: 'Order, trip and dispatch updates',
          importance: Importance.high,
        ));

    // Foreground messages -> show a local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage m) => _show(m));
    // Background (app in background) -> still delivered by FCM, but we also
    // show a local copy for consistency on Android.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => handlePayload(m.data));
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  static Future<void> _backgroundHandler(RemoteMessage m) async {
    // Optionally fire and forget a local notification via
    // flutter_local_notifications here.
  }

  Future<void> _show(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    await _local.show(
      m.messageId.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          m.data['channel'] ?? 'general',
          'General notifications',
          channelDescription: 'Order, trip and dispatch updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }
}
```

---

## 6. Token registration (backend API)

After login, register the FCM token; also refresh on `onTokenRefresh`:

```dart
Future<void> registerToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;
  await ApiService.instance.registerDeviceToken(token); // POST /api/device-token
}

// In init():
FirebaseMessaging.instance.onTokenRefresh.listen((_) => registerToken());
```

### Endpoint

`POST /api/device-token` (alias `POST /api/rider/device-token`) — requires
`Authorization: Bearer {token}`.

| Field         | Type   | Required | Notes |
|---------------|--------|----------|-------|
| `fcm_token`   | string | yes      | Firebase messaging token (max 512) |
| `device_name` | string | no       | e.g. "Samsung Galaxy A54" |
| `device_type` | string | no       | `android` / `ios` / `web` (default `android`) |
| `app_version` | string | no       | e.g. "1.2.0" |

Response `200`:

```json
{
  "success": true,
  "message": "Device token registered",
  "device": {
    "id": 3,
    "user_id": 1,
    "fcm_token": "d0x2...AbC",
    "device_name": "Samsung Galaxy A54",
    "device_type": "android",
    "app_version": "1.2.0",
    "is_active": true,
    "last_used_at": "2026-08-13T09:00:00.000000Z"
  }
}
```

The endpoint upserts by token, re-homes a token that moved to another user,
and marks the device active.

---

## 7. Logout cleanup

`DELETE /api/device-token` — deactivates + clears the token:

```json
{ "fcm_token": "d0x2...AbC" }
```

Response `200`: `{ "success": true, "message": "Device token removed" }`

Call this on logout (in addition to deleting the local token).

---

## 8. Tap deep-linking

Every notification carries these data keys:

- `type` — event type
- `screen` — target screen: `order` / `trip` / `dispatch` / `chat`
- `title`, `body` — display text
- `sent_at` — ISO timestamp
- event-specific: `order_id`, `order_number`, `tracking_session_id`, etc.

| Event | `type` | `screen` |
|---|---|---|
| New order | `order.new` | `order` |
| Order accepted | `order.accepted` | `order` |
| Order dispatched | `order.dispatched` | `order` |
| Order delivered | `order.delivered` | `order` |
| Payment success / failed | `payment.success` / `payment.failed` | `order` |
| Trip accepted | `trip.accepted` | `trip` |
| Driver arriving / arrived | `trip.driver_arriving` / `trip.driver_arrived` | `trip` |
| Trip started / in progress | `trip.started` / `trip.in_progress` | `trip` |
| Trip completed / cancelled | `trip.completed` / `trip.cancelled` | `trip` |
| New dispatch request | `dispatch.request.new` | `dispatch` |
| New message | `message.new` | `chat` |

Routing logic:

```dart
void handlePayload(Map<String, dynamic> data) {
  final type = data['type'] ?? '';
  final screen = data['screen'];
  final orderId = data['order_id'];
  final sessionId = data['tracking_session_id'];

  if (screen == 'dispatch' ||
      type.startsWith('dispatch') ||
      type == 'order.new' ||
      type == 'available' ||
      type == 'request') {
    // Switch to the "Available" tab.
  } else if (screen == 'order' && orderId != null) {
    // Open Order Detail for orderId.
  } else if (screen == 'trip' && sessionId != null) {
    // Open the live trip screen for tracking_session_id.
  } else if (screen == 'chat') {
    // Open chat.
  }
}
```

> Do **not** send GPS positions through FCM. Location uses the Reverb
> WebSocket channel (`private-tracking.session.{id}`); FCM is for alerting
> events only (new order/dispatch, trip accepted/arrived/cancelled, payment,
> messages).

---

## 9. Suggested event triggers (backend already wired)

- Customer places order → `order.new` → open **Available**.
- Rider accepts order (OrderController / DispatchRequestController) →
  `order.accepted` + `trip.accepted`.
- Trip status change → `trip.*` event per status.
- Order dispatched / delivered → `order.dispatched` / `order.delivered`.
- Payment state change → `payment.success` / `payment.failed`.
- Marketing officer sends dispatch request → `dispatch.request.new` to
  **online** riders.

---

## 10. Testing checklist

1. Run the app once so `POST /api/device-token` succeeds; confirm the token in
   the `user_devices` table (`is_active = 1`).
2. Send a test from the Firebase Console:
   **Engage → Messaging → New campaign → Android app**, targeting
   `com.feedtanstore.rider`, with a message — confirm foreground, background,
   and terminated states all show it.
3. Tap the notification in the background → app opens the correct screen.
4. Log out → confirm `DELETE /api/device-token` clears the row, then send a
   test message — it must NOT arrive.

> Test push from the terminal (replace `<TOKEN>` with a device token):
>
> ```bash
> curl -s https://fcm.googleapis.com/v1/projects/feedtanstore-50473/messages:send \
>   -H "Authorization: Bearer $(php artisan fcm:token)" \
>   -H "Content-Type: application/json" \
>   -d '{
>     "message": {
>       "token": "<TOKEN>",
>       "notification": { "title": "Test", "body": "Hello rider" },
>       "data": { "type": "order.new", "screen": "dispatch", "title": "Test", "body": "Hello rider" }
>     }
>   }'
> ```

---

*This guide matches the backend push implementation committed in
`7bcb645` (`DeviceTokenController`, `FcmClient`, `NotificationService`) and the
`FCM_*` env config in `.env`.*

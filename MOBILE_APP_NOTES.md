# FeedTan Store — Mobile App Notes (Rider / Live Tracking)

Quick-reference notes for Flutter developers consuming the FeedTan Store API.
Covers the current (verified) contract, including live trip tracking, dispatch
requests and rider profile images.

Companion docs: `API_DOCUMENTATION_RIDER.md` (full API reference),
`RIDER_MOBILE_APP_GUIDE.md` (full implementation guide).

---

## 1. Base URL & Auth

```
Base URL:  https://www.feedtanstore.com/api
Auth:      Authorization: Bearer {sanctum_token}
```

- Login: `POST /auth/login`  → `{ user, rider, token }`
  - Rejects accounts that are not riders or are deactivated.
- Logout: `POST /auth/logout` → invalidates the current token.
- Store the token securely (e.g. `flutter_secure_storage`); token is the rider
  identity — never embed it in the app bundle.

---

## 2. Rider Profile (incl. image upload)

### 2.1 GET /rider/profile
Returns `{ user, rider }`. The `rider` object now includes:

```json
"profile_image": "profile-images/abc123.jpg",
"profile_image_url": "https://www.feedtanstore.com/storage/profile-images/abc123.jpg"
```

`profile_image_url` is `null` when no image is set.

### 2.2 POST /rider/profile-image — upload
`multipart/form-data`, authenticated.

| Field    | Type | Required | Notes |
|----------|------|----------|-------|
| `image`  | file | yes      | jpeg/png/jpg/webp/gif, max 4 MB |

Response `200`:
```json
{ "message": "Profile image updated", "rider": { ... }, "profile_image": "https://.../storage/profile-images/xxx.jpg" }
```
Old image is deleted automatically on replace. Validation failure → `422`.

### 2.3 POST /rider/profile-image — remove
Send `remove=true` (multipart or form data, no file).

Response `200`:
```json
{ "message": "Profile image removed", "rider": { ... } }
```

### Flutter (Dio) example
```dart
Future<void> uploadProfileImage(File image) async {
  final form = FormData.fromMap({
    'image': await MultipartFile.fromFile(image.path, filename: image.path.split('/').last),
  });
  await _dio.post('/rider/profile-image', data: form); // Content-Type: multipart set by Dio
}

Future<void> removeProfileImage() async {
  await _dio.post('/rider/profile-image', data: {'remove': true});
}
```

Display: `Image.network(rider['profile_image_url'])` with a fallback placeholder.

---

## 3. Order Status Contract (current)

- `PUT /rider/orders/{id}/status` accepts **only** `out_for_delivery` or `delivered`.
- Marking `delivered` **requires** the customer's 4-digit `delivery_code`:

```json
{ "status": "delivered", "delivery_code": "1234", "notes": "optional" }
```
Wrong/missing code → `422` "Invalid delivery code...". Not your order → `403`.

- `POST /rider/orders/{id}/accept` — self-claim an available order or accept an
  assigned one. Enforces `packaging_status = completed` and
  `reconciliation_status = completed`. On success it sets order to
  `out_for_delivery` and returns `tracking_session_id` (a live trip starts).

- `POST /rider/orders/{id}/reject` — only for orders you have not accepted.

---

## 4. Dispatch Requests (offer board)

Marketing officer broadcasts an order to nearby riders. The offer disappears once
any rider accepts or the request expires.

| Method | Endpoint | Notes |
|--------|----------|-------|
| GET    | `/rider/dispatch-requests` | Pending offers not already responded to / not taken |
| POST   | `/rider/dispatch-requests/{id}/accept` | First-accept wins (atomic `lockForUpdate`); assigns order, starts tracking session, returns `tracking_session_id` |
| POST   | `/rider/dispatch-requests/{id}/decline` | Stays visible to other riders |

Errors: `409` already handled / already assigned / not ready.

Recommended UI: poll `GET /rider/dispatch-requests` every 10–15 s while online and
no active trip; show accept/decline on a card.

---

## 5. Live Trip Tracking (Bolt/Uber style)

### 5.1 Trip statuses (`tracking_session.status`)
`requested`, `accepted`, `driver_arriving`, `driver_arrived`, `trip_started`,
`trip_in_progress`, `trip_completed`, `cancelled`.

The rider drives the trip forward:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST   | `/tracking/location` | Send GPS fix (see payload below) — **this is the live location feed** |
| POST   | `/tracking/presence` | `{ "online": true/false }` — go online/offline |
| GET    | `/tracking/sessions` | This rider's active sessions |
| GET    | `/tracking/sessions/{id}` | Session detail |
| POST   | `/tracking/sessions/{id}/status` | `{ "status": "driver_arriving" | "driver_arrived" | "trip_started" | "trip_in_progress" | "trip_completed" | "cancelled" }` |
| POST   | `/tracking/sessions/{id}/route` | Force route recalculation from current position |

`POST /tracking/location` payload:
```json
{
  "latitude": -3.3869,
  "longitude": 36.6883,
  "heading": 90.0,
  "speed": 8.33,
  "accuracy": 6.0,
  "recorded_at": "2026-08-12T10:00:00Z",
  "tracking_session_id": 42
}
```
All fields except lat/lng optional. Backend rejects implausible jumps
(> ~162 km/h) and future/very-old timestamps (`422`).

### 5.2 Rate limits
- `tracking/location`: 1 request / 4 s per rider, 45/min.
- Other `tracking/*`: 120/min.
Send GPS at most every 4 seconds.

### 5.3 Real-time updates (Reverb WebSocket — Laravel Echo + Pusher protocol)
Subscribe to the rider's active trip channel to receive events **without** polling:

```
Channel: private-tracking.session.{sessionId}
Auth endpoint: /broadcasting/auth  (uses the same Sanctum session)
```

| Event (broadcastAs) | Payload highlights | When |
|---------------------|--------------------|------|
| `.driver.location.updated` | `driver.{lat,lng,heading,speed,accuracy}`, `distance_remaining`, `eta_seconds`, `route`, `stale` | Each accepted GPS fix |
| `.trip.status.updated` | `{ status, at, actor }` | Status change |
| `.trip.completed` | session payload | Trip completed |
| `.trip.cancelled` | session payload | Trip cancelled |

Use WebSocket for continuous position; **FCM is only for alerting events**
(trip accepted, driver arrived, trip cancelled, payment completed, new message).
Do not send GPS through FCM.

Flutter sketch:
```dart
final echo = Echo(
  connector: new PusherConnector(
    key: key, wsHost: host, wsPort: 443, wssPort: 443, useTLS: true,
    authEndpoint: '/broadcasting/auth',
  ),
);
final channel = echo.private('tracking.session.$sessionId');
channel.listen('.driver.location.updated', (e) { /* update map marker */ });
channel.listen('.trip.status.updated', (e) { /* update stepper */ });
```

---

## 6. Server-side checklist (after deploy)

```bash
git pull
php artisan migrate            # adds tracking_*, profile_image, etc.
php artisan storage:link       # required for profile images / /storage URLs
php artisan migrate:reconcile  # if a DB was imported from an older backup
```

---

## 7. Push notifications (implemented in Flutter)

Flutter side is complete and enabled (`AppConfig.firebaseEnabled = true`):

- `lib/services/push_service.dart` — Firebase init, foreground/background/terminated
  handling, local notification display, tap deep-linking.
- Token registered after login via `POST /rider/device-token`
  (`{token, platform}`). Tokens refresh automatically via `onTokenRefresh`.
- Tap behavior: notifications whose payload type suggests a new dispatch request
  (`dispatch`, `trip`, `available`, `new_order`, `request`) open the **Available**
  tab; other payloads with an order id open the order detail screen.

Required external setup (do once):

1. `android/app/google-services.json` is present and valid (project
   `feedtanstore-50473`, package `com.feedtanstore.rider`). The Google Services
   Gradle plugin is enabled in `android/app/build.gradle.kts`. The debug build
   succeeds and Firebase initializes on device.
2. iOS: add `ios/Runner/GoogleService-Info.plist` and enable the Push
   Notifications capability in Xcode (only needed when shipping iOS).
3. Laravel backend — full spec below.

### 7.1 Laravel backend spec

**Firebase project**: `feedtanstore-50473` (web API key in google-services.json
can be used as the FCM sender credential, or create a dedicated service account
for HTTP v1 — recommended).

#### a. Migration — `user_devices`

```php
Schema::create('user_devices', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->string('fcm_token', 512)->unique();
    $table->string('device_type', 20)->default('android'); // android | ios | web
    $table->string('device_name', 100)->nullable();
    $table->string('app_version', 30)->nullable();
    $table->boolean('is_active')->default(true);
    $table->timestamp('last_used_at')->nullable();
    $table->timestamps();
    $table->index(['user_id', 'is_active']);
});
```

#### b. Model — `app/Models/UserDevice.php`

```php
class UserDevice extends Model
{
    protected $fillable = [
        'user_id', 'fcm_token', 'device_type', 'device_name',
        'app_version', 'is_active', 'last_used_at',
    ];

    protected $casts = ['is_active' => 'bool', 'last_used_at' => 'datetime'];

    public function user(): BelongsTo { return $this->belongsTo(User::class); }

    public static function upsertForUser(int $userId, array $data): self
    {
        $device = self::where('user_id', $userId)
            ->where('fcm_token', $data['fcm_token'])
            ->first();
        if (! $device) {
            $device = new self(['user_id' => $userId]);
        }
        $device->fill($data);
        $device->is_active = true;
        $device->last_used_at = now();
        $device->save();
        return $device;
    }
}
```

#### c. Endpoint — register/refresh device token

`routes/api.php` (inside the rider auth group):

```php
Route::post('/rider/device-token', [DeviceTokenController::class, 'store']);
```

`app/Http/Controllers/Api/Rider/DeviceTokenController.php`:

```php
class DeviceTokenController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'token'    => ['required', 'string', 'max:512'],
            'platform' => ['sometimes', 'string', 'in:android,ios,web'],
        ]);

        UserDevice::upsertForUser($request->user()->id, [
            'fcm_token'   => $data['token'],
            'device_type' => $data['platform'] ?? 'android',
        ]);

        return response()->json(['status' => 'ok']);
    }
}
```

#### d. Service — `app/Services/PushNotificationService.php`

```php
class PushNotificationService
{
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        $tokens = $user->devices()->where('is_active', true)->pluck('fcm_token');
        $this->send($tokens->all(), $title, $body, $data);
    }

    public function send(array $tokens, string $title, string $body, array $data = []): void
    {
        foreach (array_chunk($tokens, 500) as $chunk) {
            $this->sendChunk($chunk, $title, $body, $data);
        }
    }

    protected function sendChunk(array $tokens, string $title, string $body, array $data): void
    {
        $http = Http::withToken(config('services.fcm.server_key'))
            ->asJson()
            ->post('https://fcm.googleapis.com/fcm/send', [
                'registration_ids' => $tokens,
                'priority'         => 'high',
                'notification'     => [
                    'title' => $title,
                    'body'  => $body,
                    'sound' => 'default',
                ],
                'data' => array_merge(['click_action' => 'FLUTTER_NOTIFICATION_CLICK'], $data),
            ]);

        // Best-effort: mark permanently-failed (Unavailable/NotRegistered) tokens inactive.
        if ($http->ok()) {
            $results = $http->json('results', []);
            foreach ($results as $i => $r) {
                if (isset($r['error'])) {
                    UserDevice::where('fcm_token', $tokens[$i] ?? '')
                        ->where('is_active', true)
                        ->update(['is_active' => false]);
                }
            }
        }
    }
}
```

`config/services.php`:

```php
'fcm' => [
    'server_key' => env('FCM_SERVER_KEY'),
],
```

#### e. Send on new dispatch request

When a dispatch request is created (dispatch controller / job / observer):

```php
$push = app(PushNotificationService::class);
$push->sendToUser(
    $rider,
    'New delivery available',
    "Order {$order->order_number} is ready for pickup.",
    [
        'type' => 'dispatch_request',
        'dispatch_request_id' => (string) $dispatch->id,
        'order_id' => (string) $order->id,
    ],
);
```

The Flutter app matches the `type` field (`dispatch_request` contains
"dispatch") and opens the **Available** tab; the alert is shown locally for
foreground/background/terminated states. FCM sends only on alert events; the
live map stays on WebSocket.


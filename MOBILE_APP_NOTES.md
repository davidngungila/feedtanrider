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

## 7. Push notifications (plan)

FCM tokens belong to `user_devices` (per authenticated user, multiple devices).
Register the token after login (`POST` a token-registration endpoint), handle
refresh, and deep-link taps to the trip screen via the `tracking_session_id` in
the notification payload. FCM sends only on alert events; the live map stays on
WebSocket.

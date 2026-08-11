# Feedtan Store — Rider Mobile App (Flutter) Full Implementation Guide

This guide explains how to build a **Flutter rider mobile app** that consumes the complete rider API exposed by the Feedtan Store system (`https://www.feedtanstore.com/api` or your server URL). It covers:

1. Architecture & data flow
2. Prerequisites and Flutter project setup
3. Authentication (login / token / logout)
4. The **complete API reference** — every endpoint, payload, response, and error
5. **Screen-by-screen implementation** with ready-to-use Dart code
6. Real-time location reporting (OpenStreetMap integration)
7. Push notifications (recommended)
8. Build, run, and platform permission configuration
9. Security & production checklist

---

## 1. Architecture & Data Flow

```
+--------------------------+         HTTPS + JSON          +---------------------------+
|    Flutter Rider App     | ----------------------------> |   Feedtan Store Backend    |
|   (Dio / http client)    | <---------------------------- |   Laravel 11 + Sanctum     |
+--------------------------+      Authorization: Bearer    +---------------------------+
        |  ^                        {token}                          |
        |  | periodic GPS                                          MySQL
        v  |                                                         |
   OpenStreetMap / geolocator                                DeliveryRider, OnlineOrder,
                                                              RiderLocation, RiderReview
```

- The backend is **Laravel 11** with **Laravel Sanctum** (Bearer token authentication).
- All rider endpoints are under `/api` and protected by `auth:sanctum`, except the public ones listed in section 4.6.
- Rider identity is resolved from the token's `User` record, linked to a `DeliveryRider` profile through `user_id`.

### Rider Order Lifecycle

```
Customer order placed (pending)
        |
        v
confirmed ----> preparing ----> ready ----> (rider assigned / self-claims)
        |                                     |
        |        accept  <--------------------+   rider_acceptance_status = accepted
        |                                     v
        |                              out_for_delivery
        |                                     |
        |                 deliver (requires 4-digit delivery code)
        |                                     v
        +------------------------------->  delivered
```

Key business rules enforced by the backend (matching the web dashboard):

- Riders may only **self-claim** available orders whose **packaging** and **reconciliation** are completed (`packaging_status = completed`, `reconciliation_status = completed`).
- Marking an order **delivered** requires the customer's **4-digit delivery code** (`delivery_code`).
- A rider can only update/reject orders **assigned to them**.
- Riders can move an order to `out_for_delivery` or `delivered` only.
- Deactivated riders cannot log in (`is_active = false`).

---

## 2. Prerequisites

- Flutter 3.x (stable), Dart 3.x
- Android Studio / Xcode for building
- A physical device (or emulator with GPS) to test location features

### Recommended Flutter packages

| Package | Purpose |
|---|---|
| `dio` | HTTP client with interceptors for the Bearer token |
| `flutter_secure_storage` | Securely persist the token |
| `provider` or `riverpod` | State management |
| `geolocator` | GPS permission + position stream |
| `flutter_map` + `latlong2` | OpenStreetMap display |
| `url_launcher` | Open navigation apps / support links |
| `intl` | Formatting currency (TZS) and dates |
| `firebase_messaging` (optional) | Push notifications for new orders |

### Project setup commands

```bash
flutter create feedtan_rider_app --org com.feedtanstore
cd feedtan_rider_app
flutter pub add dio flutter_secure_storage provider geolocator flutter_map latlong2 url_launcher intl
flutter pub add firebase_messaging   # optional
```

---

## 3. Base URL & Environment

Create a configuration file `lib/config.dart`:

```dart
class AppConfig {
  static const String baseUrl = 'https://www.feedtanstore.com/api';
  // Use for local testing:
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS simulator

  // Store pickup point (used to draw the route from store to customer).
  static const double storeLat = -3.3869;
  static const double storeLng = 36.6883;
}
```

---

## 4. Complete API Reference

### 4.0 General rules

- Base URL: `{{base_url}}` = `https://www.feedtanstore.com/api`
- Content-Type: `application/json`
- Auth header: `Authorization: Bearer {token}`
- Validation errors return **422** with body:
  ```json
  {
    "message": "The given data was invalid.",
    "errors": { "field": ["message..."] }
  }
  ```
- Expired/invalid token returns **401** `{ "message": "Unauthenticated." }` — the app must then force re-login.

---

### 4.1 Authentication

#### 4.1.1 Rider Login

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/auth/login` |
| **Auth** | none |

Request:
```json
{
  "email": "rider@example.com",
  "password": "password123"
}
```

Success **200**:
```json
{
  "user": {
    "id": 1, "name": "John Doe", "email": "rider@example.com",
    "phone": "255712345678", "role": "rider",
    "email_verified_at": null, "created_at": "...", "updated_at": "..."
  },
  "rider": {
    "id": 1, "name": "John Doe", "phone": "255712345678",
    "vehicle_type": "Motorcycle", "vehicle_plate": "ABC 123",
    "is_active": true, "user_id": 1, "created_at": "...", "updated_at": "..."
  },
  "token": "1|abcdefghijklmnopqrstuvwxyz1234567890"
}
```

Errors (**422**):
- `{ "message": "The provided credentials are incorrect.", "errors": { "email": ["The provided credentials are incorrect."] } }`
- `{ "message": "This account is not a delivery rider account.", ... }`
- `{ "message": "Your rider account has been deactivated. Contact support.", ... }`

> **App behavior**: store `token` in secure storage. Save `user.id`, `user.name`, and `rider.id` for offline display.

#### 4.1.2 Rider Logout

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/auth/logout` |
| **Auth** | Bearer |

Success **200**: `{ "message": "Logged out successfully" }`

> **App behavior**: delete the stored token locally regardless of the response, then navigate to Login.

---

### 4.2 Profile & Rider Details

#### 4.2.1 Get Rider Profile

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/profile` |
| **Auth** | Bearer |

Success **200**: object with `user`, `rider` (includes nested `latest_location` when available):
```json
{
  "user": { "id": 1, "name": "John Doe", "email": "rider@example.com", "phone": "255712345678", "role": "rider" },
  "rider": {
    "id": 1, "name": "John Doe", "phone": "255712345678",
    "date_of_birth": "1990-01-01", "gender": "Male", "address": "123 Main St, Moshi",
    "vehicle_type": "Motorcycle", "vehicle_plate": "ABC 123",
    "vehicle_model": "Honda CB 125", "vehicle_color": "Red", "vehicle_year": "2020",
    "nid_number": "...", "driving_license_number": "DL-123456",
    "license_expiry_date": "2030-12-31", "insurance_number": "INS-789012",
    "insurance_expiry_date": "2027-06-30",
    "bank_name": "CRDB Bank", "bank_account_number": "...", "bank_account_name": "John Doe",
    "bank_branch": "Moshi Main", "mobile_money_number": "255712345678", "mobile_money_provider": "M-Pesa",
    "total_deliveries": 150, "total_earnings": 300000, "rating": 5, "total_reviews": 45,
    "is_active": true, "user_id": 1,
    "latest_location": {
      "id": 1, "delivery_rider_id": 1, "latitude": -3.3869, "longitude": 36.6883,
      "created_at": "...", "updated_at": "..."
    }
  }
}
```

> Use this endpoint for the Profile and Settings screens.

#### 4.2.2 Update Personal Information

| | |
|---|---|
| **Method** | `PUT` |
| **URL** | `{{base_url}}/rider/personal-info` |
| **Auth** | Bearer |

Request (all optional):
```json
{ "name": "John Doe Updated", "phone": "255712345678", "date_of_birth": "1990-01-01", "gender": "Male", "address": "123 Main St, Moshi" }
```

Success **200**: `{ "message": "Personal info updated", "rider": { ...updated rider... } }`

#### 4.2.3 Get Vehicle Details

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/vehicle` |
| **Auth** | Bearer |

Success **200**:
```json
{ "vehicle_type": "Motorcycle", "vehicle_plate": "ABC 123", "vehicle_model": "Honda CB 125", "vehicle_color": "Red", "vehicle_year": "2020" }
```

#### 4.2.4 Update Vehicle Details

| | |
|---|---|
| **Method** | `PUT` |
| **URL** | `{{base_url}}/rider/vehicle` |
| **Auth** | Bearer |

Request (all optional): same fields as 4.2.3.
Success **200**: `{ "message": "Vehicle details updated", "rider": { ... } }`

#### 4.2.5 Get Documents

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/documents` |
| **Auth** | Bearer |

Success **200**:
```json
{ "nid_number": "1234567890123456", "driving_license_number": "DL-123456", "license_expiry_date": "2030-12-31", "insurance_number": "INS-789012", "insurance_expiry_date": "2027-06-30" }
```

#### 4.2.6 Update Documents

| | |
|---|---|
| **Method** | `PUT` |
| **URL** | `{{base_url}}/rider/documents` |
| **Auth** | Bearer |

Request (all optional): same fields as 4.2.5.
Success **200**: `{ "message": "Documents updated", "rider": { ... } }`

#### 4.2.7 Get Bank Details

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/bank-details` |
| **Auth** | Bearer |

Success **200**:
```json
{ "bank_name": "CRDB Bank", "bank_account_number": "...", "bank_account_name": "John Doe", "bank_branch": "Moshi Main", "mobile_money_number": "255712345678", "mobile_money_provider": "M-Pesa" }
```

#### 4.2.8 Update Bank Details

| | |
|---|---|
| **Method** | `PUT` |
| **URL** | `{{base_url}}/rider/bank-details` |
| **Auth** | Bearer |

Request (all optional): same fields as 4.2.7.
Success **200**: `{ "message": "Bank details updated", "rider": { ... } }`

---

### 4.3 Performance & Reviews

#### 4.3.1 Get Performance Statistics

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/performance` |
| **Auth** | Bearer |

Success **200**:
```json
{
  "total_deliveries": 150,
  "total_earnings": 300000,
  "rating": 5,
  "total_reviews": 45,
  "today_deliveries": 5,
  "this_week_deliveries": 25,
  "this_month_deliveries": 60
}
```

> Note: `rating` is an integer (0-5) on the backend.

#### 4.3.2 Get Customer Reviews

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/reviews` |
| **Auth** | Bearer |

Success **200**: Laravel paginator
```json
{
  "current_page": 1,
  "data": [
    {
      "id": 1, "delivery_rider_id": 1, "online_order_id": 1,
      "customer_name": "Jane Smith", "customer_email": "jane@example.com",
      "rating": 5, "comment": "Excellent service, on time!",
      "created_at": "...", "updated_at": "..."
    }
  ],
  "first_page_url": "...", "from": 1, "last_page": 3, "last_page_url": "...",
  "links": [ ... ], "next_page_url": "...?page=2", "path": "...",
  "per_page": 10, "prev_page_url": null, "to": 10, "total": 23
}
```

> Paginate with `?page=N`. Show `total` / `last_page` for pagination controls.

---

### 4.4 Location

#### 4.4.1 Update Rider Location

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/rider/location` |
| **Auth** | Bearer |

Request:
```json
{ "latitude": -3.3869, "longitude": 36.6883 }
```

Success **200**: `{ "message": "Location updated" }`
Error **422** when latitude/longitude missing or non-numeric.

> **App behavior**: call this periodically (e.g. every 15-30 s while the app is in the foreground, and on every significant movement). Each call inserts a `RiderLocation` row; the admin map and customer tracking read the **latest** one.

#### 4.4.2 Get Rider Location

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/location/{riderId}` |
| **Auth** | Bearer |

Path param: `riderId` — the `delivery_rider_id` (integer).

Success **200**:
```json
{ "id": 1, "delivery_rider_id": 1, "latitude": -3.3869, "longitude": 36.6883, "created_at": "...", "updated_at": "..." }
```
If the rider has no location yet the body is `null`.

---

### 4.5 Orders

#### 4.5.1 Get My Orders (assigned)

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/orders` |
| **Auth** | Bearer |

Success **200**: array of order objects (shape in 4.5.3), newest first. Includes orders with `rider_acceptance_status` = `pending`, `accepted`, and already-delivered ones.

> **App behavior**: split this list client-side into tabs — **Pending** (acceptance pending), **Active** (out_for_delivery), **Completed** (delivered/cancelled) — using the `status` / `rider_acceptance_status` fields.

#### 4.5.2 Get Available Orders (claimable)

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/orders/available` |
| **Auth** | Bearer |

Success **200**: array of orders that are **confirmed, not assigned to any rider, and fully packaged + reconciled**. These can be claimed with the accept endpoint (4.5.4).

#### 4.5.3 Get Order Details

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/orders/{id}` |
| **Auth** | Bearer |

Success **200** — full order object:
```json
{
  "id": 1,
  "order_number": "ORD-ABC123",
  "tracking_token": "abcdef123456",
  "delivery_code": "1234",
  "customer_id": 1,
  "customer_name": "Jane Smith",
  "customer_phone": "255711223344",
  "customer_email": "jane@example.com",
  "delivery_address": "123 Main St, Moshi",
  "delivery_latitude": -3.36,
  "delivery_longitude": 36.7,
  "status": "confirmed",
  "packaging_status": "completed",
  "reconciliation_status": "completed",
  "payment_status": "pending",
  "payment_method": "cash",
  "payment_transaction_id": null,
  "payment_order_reference": null,
  "clickpesa_status": null,
  "subtotal": 15000,
  "discount": 0,
  "delivery_fee": 2000,
  "total": 17000,
  "delivery_rider_id": 1,
  "user_id": null,
  "notes": "Leave at front door",
  "is_processed": false,
  "rider_acceptance_status": "pending",
  "rider_accepted_at": null,
  "created_at": "...",
  "updated_at": "...",
  "items": [
    {
      "id": 1, "online_order_id": 1, "product_id": 1,
      "quantity": 2, "price": 7500, "total": 15000,
      "product": { "id": 1, "name": "Product Name", "description": "...", "price": 7500, "quantity": 50 }
    }
  ],
  "customer": { "id": 1, "name": "Jane Smith", "phone": "255711223344", "email": "jane@example.com" },
  "rider": { "id": 1, "name": "John Doe", "phone": "255712345678", "vehicle_type": "Motorcycle", "vehicle_plate": "ABC 123", "is_active": true },
  "status_history": [
    {
      "id": 1, "online_order_id": 1, "status": "out_for_delivery",
      "payment_status": "pending", "notes": "Order accepted by rider via API (status changed from confirmed to out_for_delivery)",
      "user_id": 1, "created_at": "...", "updated_at": "..."
    }
  ]
}
```

> Note: `status_history` items contain a single `status` (the state after the change), `notes` describing the transition, and `user_id` of whoever changed it.

#### 4.5.4 Accept an Order

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/rider/orders/{id}/accept` |
| **Auth** | Bearer |

Used for both **admin-assigned pending orders** and **self-claiming available orders**.

Success **200**:
```json
{
  "message": "Order accepted",
  "order": {
    "id": 2, "order_number": "ORD-DEF456", "status": "out_for_delivery",
    "delivery_rider_id": 1, "rider_acceptance_status": "accepted",
    "rider_accepted_at": "2026-07-10T10:30:00.000000Z"
  }
}
```

Errors (**400**):
- `{ "message": "Order already assigned to another rider" }`
- `{ "message": "Order already accepted" }`
- `{ "message": "Order packaging is not completed yet" }`
- `{ "message": "Order reconciliation is not completed yet" }`

#### 4.5.5 Reject an Order

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/rider/orders/{id}/reject` |
| **Auth** | Bearer |

Only for **assigned orders** whose acceptance is still `pending`.

Success **200**:
```json
{
  "message": "Order rejected",
  "order": {
    "id": 1, "order_number": "ORD-ABC123", "status": "confirmed",
    "delivery_rider_id": null, "rider_acceptance_status": "rejected"
  }
}
```

Errors (**400**):
- `{ "message": "Order not assigned to you" }`
- `{ "message": "Cannot reject accepted order" }`

#### 4.5.6 Update Order Status

| | |
|---|---|
| **Method** | `PUT` |
| **URL** | `{{base_url}}/rider/orders/{id}/status` |
| **Auth** | Bearer |

Request:
```json
{
  "status": "delivered",
  "delivery_code": "1234",
  "notes": "Delivered successfully"
}
```

- `status` must be `out_for_delivery` or `delivered`.
- `delivery_code` is **required when `status = delivered`** — the customer shows this 4-digit code at the door.
- `notes` is optional.

Success **200**: `{ "message": "Order status updated", "order": { "id": 1, "status": "delivered" } }`

Errors:
- **403** `{ "message": "Order not assigned to you" }`
- **422** `{ "message": "Invalid delivery code. Please enter the correct 4-digit code.", "errors": {...} }`
- **500** `{ "message": "Failed to update order status" }`

---

### 4.6 Rider Dispatch Requests (New Delivery Request Flow)

The marketing officer no longer assigns a rider directly. Instead the officer sends a **dispatch request** which is broadcast to all available riders. The first rider to **accept** gets the order assigned immediately, and the request **disappears from every other rider's app**.

The app should **poll** `GET /rider/dispatch-requests` (e.g. every 10-30 seconds, or on a push notification) so new requests appear live.

#### 4.6.1 Get Pending Dispatch Requests

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider/dispatch-requests` |
| **Auth** | Bearer |

Success **200**: array of pending dispatch requests (each includes the full order with `items` and `customer`):
```json
[
  {
    "id": 1,
    "online_order_id": 108,
    "status": "pending",
    "accepted_rider_id": null,
    "accepted_at": null,
    "expires_at": "2026-08-11T15:30:00.000000Z",
    "created_at": "...",
    "updated_at": "...",
    "order": {
      "id": 108, "order_number": "ORD-ABC108", "customer_name": "Jane Smith",
      "customer_phone": "255711223344", "delivery_address": "123 Main St, Moshi",
      "delivery_latitude": -3.36, "delivery_longitude": 36.7,
      "status": "confirmed", "payment_status": "paid", "payment_method": "online",
      "subtotal": 15000, "delivery_fee": 2000, "total": 17000,
      "items": [ { "id": 1, "product_id": 1, "quantity": 2, "price": 7500, "total": 15000, "product": { "id": 1, "name": "Product Name" } } ],
      "customer": { "id": 1, "name": "Jane Smith", "phone": "255711223344", "email": "jane@example.com" }
    }
  }
]
```

Rules enforced by the backend:
- Only requests with `status = pending` for orders that still have **no rider** are returned.
- A request already **accepted** by another rider is not returned (disappears for everyone else).
- A request the rider has already **accepted or declined** is not returned to that rider.
- Requests expire automatically after the expiry time (shown as `expires_at`, ~30 minutes) and are removed from the list.

#### 4.6.2 Accept a Dispatch Request

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/rider/dispatch-requests/{id}/accept` |
| **Auth** | Bearer |

Success **200**:
```json
{
  "message": "Dispatch request accepted. Order assigned to you.",
  "order": {
    "id": 108, "status": "out_for_delivery", "delivery_rider_id": 1,
    "rider_acceptance_status": "accepted", "rider_accepted_at": "2026-08-11T14:00:00.000000Z"
  }
}
```

Errors:
- **409** `{ "message": "This dispatch request has already been handled" }` — another rider accepted first; refresh the list.
- **409** `{ "message": "Order already assigned to another rider" }`
- **409** `{ "message": "Order is not ready for dispatch" }`

> **App behavior**: on success, play a notification, move the order into the rider's **Active** deliveries, and open navigation.

#### 4.6.3 Decline a Dispatch Request

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `{{base_url}}/rider/dispatch-requests/{id}/decline` |
| **Auth** | Bearer |

Success **200**: `{ "message": "Dispatch request declined" }`

The request stays pending for **other** riders but will not be shown to this rider again.

---

### 4.7 Public Endpoints (No Auth)

#### 4.7.1 Terms & Policies

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/terms-policies` |

Success **200**:
```json
{
  "terms_of_service": "...",
  "privacy_policy": "...",
  "rider_terms": "...",
  "rider_privacy_policy": "..."
}
```

#### 4.7.2 Rider Support

| | |
|---|---|
| **Method** | `GET` |
| **URL** | `{{base_url}}/rider-support` |

Success **200**:
```json
{
  "support_email": "support@feedtanstore.com",
  "support_phone": "255712345678",
  "support_address": "123 Main St, Moshi, Tanzania"
}
```

> Use with `url_launcher` for `mailto:` / `tel:` actions.

#### 4.7.3 Real-Time Data (used by dashboards / debugging)

| Endpoint | Description |
|---|---|
| `GET {{base_url}}/realtime/riders` | All riders with their `latest_location` (or null) |
| `GET {{base_url}}/realtime/orders` | Orders that have delivery coordinates, with nested `rider` and `items.product` |

### 4.8 Data Models (Dart)

```dart
class RiderLocation {
  final int id;
  final int deliveryRiderId;
  final double latitude;
  final double longitude;
  final String createdAt;

  RiderLocation.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        deliveryRiderId = j['delivery_rider_id'],
        latitude = (j['latitude'] as num).toDouble(),
        longitude = (j['longitude'] as num).toDouble(),
        createdAt = j['created_at'] ?? '';
}

class Rider {
  final int id;
  final String name;
  final String phone;
  final String? dateOfBirth, gender, address;
  final String? vehicleType, vehiclePlate, vehicleModel, vehicleColor, vehicleYear;
  final String? nidNumber, drivingLicenseNumber, licenseExpiryDate;
  final String? insuranceNumber, insuranceExpiryDate;
  final String? bankName, bankAccountNumber, bankAccountName, bankBranch;
  final String? mobileMoneyNumber, mobileMoneyProvider;
  final int totalDeliveries, totalEarnings, rating, totalReviews;
  final bool isActive;
  final RiderLocation? latestLocation;

  Rider.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        phone = j['phone'],
        dateOfBirth = j['date_of_birth'],
        gender = j['gender'],
        address = j['address'],
        vehicleType = j['vehicle_type'],
        vehiclePlate = j['vehicle_plate'],
        vehicleModel = j['vehicle_model'],
        vehicleColor = j['vehicle_color'],
        vehicleYear = j['vehicle_year'],
        nidNumber = j['nid_number'],
        drivingLicenseNumber = j['driving_license_number'],
        licenseExpiryDate = j['license_expiry_date'],
        insuranceNumber = j['insurance_number'],
        insuranceExpiryDate = j['insurance_expiry_date'],
        bankName = j['bank_name'],
        bankAccountNumber = j['bank_account_number'],
        bankAccountName = j['bank_account_name'],
        bankBranch = j['bank_branch'],
        mobileMoneyNumber = j['mobile_money_number'],
        mobileMoneyProvider = j['mobile_money_provider'],
        totalDeliveries = j['total_deliveries'] ?? 0,
        totalEarnings = j['total_earnings'] ?? 0,
        rating = j['rating'] ?? 0,
        totalReviews = j['total_reviews'] ?? 0,
        isActive = j['is_active'] ?? true,
        latestLocation = j['latest_location'] != null
            ? RiderLocation.fromJson(j['latest_location'])
            : null;
}

class RiderReview {
  final int id;
  final String? customerName, comment;
  final int rating;
  final String createdAt;

  RiderReview.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        customerName = j['customer_name'],
        comment = j['comment'],
        rating = j['rating'],
        createdAt = j['created_at'] ?? '';
}

class OrderItem {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final double total;
  final String productName;

  OrderItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        productId = j['product_id'],
        quantity = j['quantity'],
        price = (j['price'] as num).toDouble(),
        total = (j['total'] as num).toDouble(),
        productName = j['product']?['name'] ?? 'Unknown product';
}

class StatusHistory {
  final int id;
  final String status;
  final String? notes;
  final String createdAt;

  StatusHistory.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        status = j['status'],
        notes = j['notes'],
        createdAt = j['created_at'] ?? '';
}

class OnlineOrder {
  final int id;
  final String orderNumber;
  final String deliveryCode;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? deliveryLatitude, deliveryLongitude;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final double subtotal, discount, deliveryFee, total;
  final int? deliveryRiderId;
  final String? notes;
  final String? riderAcceptanceStatus;
  final String? riderAcceptedAt;
  final List<OrderItem> items;
  final List<StatusHistory> statusHistory;

  OnlineOrder.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        orderNumber = j['order_number'],
        deliveryCode = j['delivery_code'] ?? '',
        customerName = j['customer_name'],
        customerPhone = j['customer_phone'],
        deliveryAddress = j['delivery_address'] ?? '',
        deliveryLatitude = j['delivery_latitude'] != null
            ? (j['delivery_latitude'] as num).toDouble() : null,
        deliveryLongitude = j['delivery_longitude'] != null
            ? (j['delivery_longitude'] as num).toDouble() : null,
        status = j['status'],
        paymentStatus = j['payment_status'],
        paymentMethod = j['payment_method'],
        subtotal = (j['subtotal'] as num).toDouble(),
        discount = (j['discount'] ?? 0).toDouble(),
        deliveryFee = (j['delivery_fee'] ?? 0).toDouble(),
        total = (j['total'] as num).toDouble(),
        deliveryRiderId = j['delivery_rider_id'],
        notes = j['notes'],
        riderAcceptanceStatus = j['rider_acceptance_status'],
        riderAcceptedAt = j['rider_accepted_at'],
        items = (j['items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e)).toList(),
        statusHistory = (j['status_history'] as List? ?? [])
            .map((e) => StatusHistory.fromJson(e)).toList();

  bool get needsAcceptance => riderAcceptanceStatus == 'pending';
  bool get isActiveDelivery => status == 'out_for_delivery';
  bool get isDelivered => status == 'delivered';
}
```

---

## 5. API Service Layer (Dio)

`lib/services/api_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  // ---- Token handling ----
  Future<String?> get token async => _storage.read(key: _tokenKey);
  Future<void> saveToken(String t) async => _storage.write(key: _tokenKey, value: t);
  Future<void> clearToken() async => _storage.delete(key: _tokenKey);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await saveToken(res.data['token'] as String);
    return res.data;
  }

  Future<void> logout() async {
    final t = await token;
    if (t != null) {
      try { await _authed(t).post('/auth/logout'); } catch (_) {}
    }
    await clearToken();
  }

  Dio _authed(String? t) {
    _dio.options.headers['Authorization'] = t != null ? 'Bearer $t' : null;
    return _dio;
  }

  Future<Dio> _client() async => _authed(await token);

  // ---- Profile ----
  Future<Map<String, dynamic>> getProfile() async =>
      (await (await _client()).get('/rider/profile')).data;
  Future<Map<String, dynamic>> updatePersonalInfo(Map<String, dynamic> d) async =>
      (await (await _client()).put('/rider/personal-info', data: d)).data;
  Future<Map<String, dynamic>> getVehicle() async =>
      (await (await _client()).get('/rider/vehicle')).data;
  Future<Map<String, dynamic>> updateVehicle(Map<String, dynamic> d) async =>
      (await (await _client()).put('/rider/vehicle', data: d)).data;
  Future<Map<String, dynamic>> getDocuments() async =>
      (await (await _client()).get('/rider/documents')).data;
  Future<Map<String, dynamic>> updateDocuments(Map<String, dynamic> d) async =>
      (await (await _client()).put('/rider/documents', data: d)).data;
  Future<Map<String, dynamic>> getBankDetails() async =>
      (await (await _client()).get('/rider/bank-details')).data;
  Future<Map<String, dynamic>> updateBankDetails(Map<String, dynamic> d) async =>
      (await (await _client()).put('/rider/bank-details', data: d)).data;

  // ---- Performance & Reviews ----
  Future<Map<String, dynamic>> getPerformance() async =>
      (await (await _client()).get('/rider/performance')).data;
  Future<Map<String, dynamic>> getReviews({int page = 1}) async =>
      (await (await _client()).get('/rider/reviews', queryParameters: {'page': page})).data;

  // ---- Location ----
  Future<void> updateLocation(double lat, double lng) async =>
      (await _client()).post('/rider/location', data: {'latitude': lat, 'longitude': lng});

  // ---- Orders ----
  Future<List<dynamic>> getMyOrders() async =>
      (await (await _client()).get('/rider/orders')).data as List;
  Future<List<dynamic>> getAvailableOrders() async =>
      (await (await _client()).get('/rider/orders/available')).data as List;

  // ---- Dispatch Requests (new delivery request flow) ----
  Future<List<dynamic>> getDispatchRequests() async =>
      (await (await _client()).get('/rider/dispatch-requests')).data as List;
  Future<Map<String, dynamic>> acceptDispatchRequest(int id) async =>
      (await (await _client()).post('/rider/dispatch-requests/$id/accept')).data;
  Future<Map<String, dynamic>> declineDispatchRequest(int id) async =>
      (await (await _client()).post('/rider/dispatch-requests/$id/decline')).data;
  Future<Map<String, dynamic>> getOrder(int id) async =>
      (await (await _client()).get('/rider/orders/$id')).data;
  Future<Map<String, dynamic>> acceptOrder(int id) async =>
      (await (await _client()).post('/rider/orders/$id/accept')).data;
  Future<Map<String, dynamic>> rejectOrder(int id) async =>
      (await (await _client()).post('/rider/orders/$id/reject')).data;
  Future<Map<String, dynamic>> updateOrderStatus(
    int id, String status, {String? deliveryCode, String? notes}) async =>
      (await (await _client()).put('/rider/orders/$id/status', data: {
        'status': status,
        if (deliveryCode != null) 'delivery_code': deliveryCode,
        if (notes != null) 'notes': notes,
      })).data;
}
```

**Auto 401 handling (recommended)** — add a Dio interceptor: on a `DioException` with status 401, clear the token and emit a "session expired" event so the app navigates to the Login screen.

---

## 6. Screen-by-Screen Implementation

Recommended navigation structure (bottom tabs):

```
Splash Screen  ->  Login Screen
                     |
                     v
                  Main Shell (IndexedStack of 4 tabs)
                     |- Dashboard   (performance + quick actions)
                     |- Available   (claimable orders)
                     |- My Orders   (pending / active / completed tabs)
                     '- Profile     (profile, edit forms, performance, reviews, support, logout)

Full-screen route: Order Detail  (from Available / My Orders) -> OSM map + delivery actions
```

### 6.1 Login Screen

- Fields: email, password (obscured).
- On submit: call `ApiService.instance.login(...)`.
- Show errors from `errors.email` / `errors.password` (422), otherwise a generic network error.
- On success: navigate to `MainShell`.

```dart
Future<void> _submit() async {
  setState(() => _loading = true);
  try {
    await ApiService.instance.login(_email.text.trim(), _password.text);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  } on DioException catch (e) {
    final msg = e.response?.data?['errors']?['email']?[0]
        ?? e.response?.data?['message']
        ?? 'Login failed. Check your connection.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } finally {
    setState(() => _loading = false);
  }
}
```

> On app launch, check for a stored token in the Splash screen; if present, go straight to `MainShell` (and verify with `getProfile()`).

### 6.2 Dashboard (Home)

Fetch `getPerformance()` + `getMyOrders()` in parallel. Cards:

- Today / This week / This month deliveries
- Rating (out of 5) with review count
- Total deliveries and total earnings (TZS)
- Quick actions: *Available Orders*, *My Orders*, *My Profile*

Format currency with `intl`: `NumberFormat.currency(locale: 'en_TZ', symbol: 'TZS', decimalDigits: 0)`.

### 6.3 Available Orders (Dispatch Requests)

**Primary flow** (new): the marketing officer sends a **dispatch request** instead of assigning directly.
- `GET /rider/dispatch-requests` (poll every ~15s, plus on app resume / FCM push) -> list of pending requests, each with the full `order` object.
- Each card: order number, customer name, address, item count, subtotal + delivery fee + total, payment method badge, and an **expires in** countdown from `expires_at`.
- **Accept** button -> confirm dialog -> `acceptDispatchRequest(id)`.
  - Success: snackbar, move order into **My Orders → Active**, prompt "Open navigation?".
  - On 409 "already been handled": show the message and refresh the list (another rider won).
- **Decline** button -> `declineDispatchRequest(id)` -> removes the card; the request stays pending for other riders.

**Legacy flow**: `GET /rider/orders/available` still returns unassigned orders, but dispatch requests are the recommended path going forward.

### 6.4 My Orders (Assigned)

- `GET /rider/orders` -> group into three tabs:

| Tab | Filter |
|---|---|
| Pending | `riderAcceptanceStatus == 'pending'` |
| Active | `status == 'out_for_delivery'` |
| Completed | `status == 'delivered'` or `cancelled` |

- Pending tab: **Accept** and **Reject** buttons.
  - Reject -> confirm dialog -> `rejectOrder(id)`. On 400 "Cannot reject accepted order", refresh.
- Active tab: tap to open Order Detail for navigation + delivery.
- Use `RefreshIndicator` on every list.

### 6.5 Order Detail

Screen layout (top to bottom):

1. **Status banner** — colored chip per status (confirmed / preparing / ready / out_for_delivery / delivered / cancelled).
2. **Customer card** — name, phone (`tel:` via `url_launcher`), address.
3. **Order summary** — subtotal, discount, delivery fee, **total**.
4. **Items list** — product name x quantity, line total.
5. **Notes** (if any).
6. **Order timeline** — from `statusHistory`, reversed.
7. **Map + actions** — see 6.6 — for active orders.
8. **Delivery confirmation** — when status is `out_for_delivery`, a "Mark as Delivered" button opens a dialog asking for the customer's **4-digit delivery code** -> `updateOrderStatus(id, 'delivered', deliveryCode: code)`.

`updateStatus` error handling:

- **422 invalid code** -> inline error "Invalid delivery code".
- **403** -> order no longer assigned; refresh and return to list.
- **500** -> friendly retry-later message.

### 6.6 Map & Navigation (OpenStreetMap)

Use `flutter_map` + `geolocator`. Markers:

- Store pickup point (`AppConfig.storeLat/storeLng`).
- Customer delivery point (`order.deliveryLatitude/Longitude`).
- Rider current position (live).

```dart
class OrderMapView extends StatefulWidget {
  final OnlineOrder order;
  final LatLng? riderPosition;
  const OrderMapView({super.key, required this.order, this.riderPosition});
  @override
  State<OrderMapView> createState() => _OrderMapViewState();
}

class _OrderMapViewState extends State<OrderMapView> {
  @override
  Widget build(BuildContext context) {
    final store = LatLng(AppConfig.storeLat, AppConfig.storeLng);
    final destination = (widget.order.deliveryLatitude != null &&
            widget.order.deliveryLongitude != null)
        ? LatLng(widget.order.deliveryLatitude!, widget.order.deliveryLongitude!)
        : null;
    return FlutterMap(
      options: MapOptions(
        initialCenter: widget.riderPosition ?? store,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.feedtanstore.rider',
        ),
        if (widget.riderPosition != null)
          MarkerLayer(markers: [
            Marker(
              point: widget.riderPosition!,
              width: 40, height: 40,
              child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 36),
            ),
          ]),
        if (destination != null)
          MarkerLayer(markers: [
            Marker(
              point: store,
              width: 32, height: 32,
              child: const Icon(Icons.store, color: Colors.green, size: 30),
            ),
            Marker(
              point: destination,
              width: 32, height: 32,
              child: const Icon(Icons.location_on, color: Colors.red, size: 34),
            ),
          ]),
      ],
    );
  }
}
```

**Navigation**: use `url_launcher` with `geo:` or `google.navigation:` URIs so the rider can open turn-by-turn directions:

```dart
Future<void> openNavigation(LatLng destination) async {
  final url = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
```

---

## 7. Real-Time Location Reporting

Create a location service using `geolocator` and report to `/rider/location`:

```dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _sub;

  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse
        || permission == LocationPermission.always;
  }

  void startReporting() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,          // update when moving 20 m
        timeLimit: null,
      ),
    ).listen((pos) async {
      try {
        await ApiService.instance.updateLocation(pos.latitude, pos.longitude);
      } catch (_) {
        // offline - retry on next tick
      }
    });
  }

  void stopReporting() => _sub?.cancel();
}
```

Guidelines:

- Start reporting right after login and stop on logout.
- While the rider has an **active delivery**, report every 15-30 s and on every 20 m of movement.
- If background location is required, request `LocationPermission.always` and add the Android/iOS background permission entries (section 9).

---

## 8. Push Notifications (Recommended)

The backend does not currently emit real-time push messages. Two options:

1. **Polling** (simplest, works immediately): refresh `/rider/orders` and `/rider/orders/available` every 30-60 s in the background and notify the rider when a new `pending` order appears.
2. **FCM** (better UX): integrate `firebase_messaging`, register the device token, and have the backend store it (e.g. in `user_devices`) and send a notification when a rider is assigned an order.

Suggested notification events:

- New order assigned (pending acceptance).
- Order status changed by the shop.

---

## 9. Platform Permission Configuration

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- only if background tracking is needed -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<application
    android:label="Feedtan Rider"
    android:usesCleartextTraffic="false">
  ...
</application>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to navigate to deliveries and show your position to the shop.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Your location is shared so customers can track their delivery.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Your location is shared so customers can track their delivery.</string>
```

Also enable background location capability in Xcode if tracking in the background is required.

> **Cleartext note**: for local testing against `http://10.0.2.2:8000`, temporarily set `android:usesCleartextTraffic="true"` or add a network security config. In production the app must use HTTPS (`https://www.feedtanstore.com`).

---

## 10. Security & Production Checklist

- [ ] Use **HTTPS only** in production; never ship a hardcoded `http://` base URL.
- [ ] Store the token in **secure storage** (`flutter_secure_storage`), never in plain `SharedPreferences`.
- [ ] Do **not** log the token or password anywhere.
- [ ] Handle **401** globally and force re-login (session expiry).
- [ ] Validate the **delivery code** client-side (4 digits) before calling the API to reduce wasted requests.
- [ ] Do not auto-accept orders silently; always confirm with the rider.
- [ ] Keep location reporting off when the app is backgrounded (unless the product requires background tracking and it is disclosed in the privacy policy).
- [ ] Keep packages updated (`flutter pub upgrade`) and test on both Android and iOS.
- [ ] On every build, verify the backend routes exist via `php artisan route:list --path=api`.

---

## Appendix A — Endpoint Summary Table

| # | Method | Endpoint | Auth | Purpose |
|---|---|---|---|---|
| 1 | POST | `/auth/login` | - | Login, get token |
| 2 | POST | `/auth/logout` | Bearer | Invalidate token |
| 3 | GET | `/rider/profile` | Bearer | Profile + latest location |
| 4 | PUT | `/rider/personal-info` | Bearer | Update personal info |
| 5 | GET | `/rider/vehicle` | Bearer | Get vehicle details |
| 6 | PUT | `/rider/vehicle` | Bearer | Update vehicle details |
| 7 | GET | `/rider/documents` | Bearer | Get documents |
| 8 | PUT | `/rider/documents` | Bearer | Update documents |
| 9 | GET | `/rider/bank-details` | Bearer | Get bank details |
| 10 | PUT | `/rider/bank-details` | Bearer | Update bank details |
| 11 | GET | `/rider/performance` | Bearer | Performance stats |
| 12 | GET | `/rider/reviews` | Bearer | Paginated reviews |
| 13 | POST | `/rider/location` | Bearer | Report GPS |
| 14 | GET | `/rider/location/{riderId}` | Bearer | Get rider location |
| 15 | GET | `/rider/orders` | Bearer | My assigned orders |
| 16 | GET | `/rider/orders/available` | Bearer | Claimable orders |
| 17 | GET | `/rider/orders/{id}` | Bearer | Order details |
| 18 | POST | `/rider/orders/{id}/accept` | Bearer | Accept/claim order |
| 19 | POST | `/rider/orders/{id}/reject` | Bearer | Reject order |
| 20 | PUT | `/rider/orders/{id}/status` | Bearer | Update status (+delivery code) |
| 21 | GET | `/terms-policies` | - | Terms & policies |
| 22 | GET | `/rider-support` | - | Support contacts |
| 23 | GET | `/realtime/riders` | - | All riders + locations |
| 24 | GET | `/realtime/orders` | - | All orders with coords |

---

*This guide corresponds to the API implemented in the Feedtan Store backend (`routes/api.php`, `Api\RiderController`, `Api\OrderController`, `Api\AuthController`). All endpoint shapes above were verified against the current controllers.*




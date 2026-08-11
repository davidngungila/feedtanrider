int _asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _asDouble(Object? v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

String _asStr(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

int? _asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class RiderLocation {
  final int id;
  final int deliveryRiderId;
  final double latitude;
  final double longitude;
  final String createdAt;

  RiderLocation.fromJson(Map<String, dynamic> j)
      : id = _asInt(j['id']),
        deliveryRiderId = _asInt(j['delivery_rider_id']),
        latitude = _asDouble(j['latitude']),
        longitude = _asDouble(j['longitude']),
        createdAt = _asStr(j['created_at']);
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
  final String? profileImage, profileImageUrl;
  final int totalDeliveries, totalEarnings, rating, totalReviews;
  final bool isActive;
  final RiderLocation? latestLocation;

  Rider.fromJson(Map<String, dynamic> j)
      : id = _asInt(j['id']),
        name = _asStr(j['name'], 'Rider'),
        phone = _asStr(j['phone']),
        dateOfBirth = j['date_of_birth']?.toString(),
        gender = j['gender']?.toString(),
        address = j['address']?.toString(),
        vehicleType = j['vehicle_type']?.toString(),
        vehiclePlate = j['vehicle_plate']?.toString(),
        vehicleModel = j['vehicle_model']?.toString(),
        vehicleColor = j['vehicle_color']?.toString(),
        vehicleYear = j['vehicle_year']?.toString(),
        nidNumber = j['nid_number']?.toString(),
        drivingLicenseNumber = j['driving_license_number']?.toString(),
        licenseExpiryDate = j['license_expiry_date']?.toString(),
        insuranceNumber = j['insurance_number']?.toString(),
        insuranceExpiryDate = j['insurance_expiry_date']?.toString(),
        bankName = j['bank_name']?.toString(),
        bankAccountNumber = j['bank_account_number']?.toString(),
        bankAccountName = j['bank_account_name']?.toString(),
        bankBranch = j['bank_branch']?.toString(),
        mobileMoneyNumber = j['mobile_money_number']?.toString(),
        mobileMoneyProvider = j['mobile_money_provider']?.toString(),
        profileImage = j['profile_image']?.toString(),
        profileImageUrl = j['profile_image_url']?.toString(),
        totalDeliveries = _asInt(j['total_deliveries']),
        totalEarnings = _asInt(j['total_earnings']),
        rating = _asInt(j['rating']),
        totalReviews = _asInt(j['total_reviews']),
        isActive = j['is_active'] == true || j['is_active'] == 1,
        latestLocation = j['latest_location'] != null
            ? RiderLocation.fromJson(j['latest_location'] as Map<String, dynamic>)
            : null;

  String get initials {
    final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'R';
    return parts.take(2).map((w) => w[0]).join().toUpperCase();
  }

  bool get hasProfileImage => profileImageUrl != null && profileImageUrl!.isNotEmpty;
}

class RiderReview {
  final int id;
  final String? customerName, comment;
  final int rating;
  final String createdAt;

  RiderReview.fromJson(Map<String, dynamic> j)
      : id = _asInt(j['id']),
        customerName = j['customer_name']?.toString(),
        comment = j['comment']?.toString(),
        rating = _asInt(j['rating']),
        createdAt = _asStr(j['created_at']);
}

class OrderItem {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final double total;
  final String productName;

  OrderItem.fromJson(Map<String, dynamic> j)
      : id = _asInt(j['id']),
        productId = _asInt(j['product_id']),
        quantity = _asInt(j['quantity']),
        price = _asDouble(j['price']),
        total = _asDouble(j['total']),
        productName = _asStr(
          j['product'] is Map ? (j['product'] as Map)['name'] : j['product_name'],
          'Unknown product',
        );
}

class StatusHistory {
  final int id;
  final String status;
  final String? notes;
  final String createdAt;

  StatusHistory.fromJson(Map<String, dynamic> j)
      : id = _asInt(j['id']),
        status = _asStr(j['status'], 'Unknown'),
        notes = j['notes']?.toString(),
        createdAt = _asStr(j['created_at']);
}

class OnlineOrder {
  final int id;
  final String orderNumber;
  final String deliveryCode;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String deliveryAddress;
  final double? deliveryLatitude, deliveryLongitude;
  final String status;
  final String packagingStatus;
  final String reconciliationStatus;
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
      : id = _asInt(j['id']),
        orderNumber = _asStr(j['order_number']),
        deliveryCode = _asStr(j['delivery_code']),
        customerName = _asStr(j['customer_name'], 'Customer'),
        customerPhone = _asStr(j['customer_phone']),
        customerEmail = _asStr(j['customer_email']),
        deliveryAddress = _asStr(j['delivery_address']),
        deliveryLatitude = _asDoubleOrNull(j['delivery_latitude']),
        deliveryLongitude = _asDoubleOrNull(j['delivery_longitude']),
        status = _asStr(j['status'], 'pending'),
        packagingStatus = _asStr(j['packaging_status']),
        reconciliationStatus = _asStr(j['reconciliation_status']),
        paymentStatus = _asStr(j['payment_status']),
        paymentMethod = j['payment_method']?.toString(),
        subtotal = _asDouble(j['subtotal']),
        discount = _asDouble(j['discount']),
        deliveryFee = _asDouble(j['delivery_fee']),
        total = _asDouble(j['total']),
        deliveryRiderId = _asIntOrNull(j['delivery_rider_id']),
        notes = j['notes']?.toString(),
        riderAcceptanceStatus = j['rider_acceptance_status']?.toString(),
        riderAcceptedAt = j['rider_accepted_at']?.toString(),
        items = (j['items'] is List ? j['items'] as List : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((e) => OrderItem.fromJson(e))
            .toList(),
        statusHistory =
            (j['status_history'] is List ? j['status_history'] as List : const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map((e) => StatusHistory.fromJson(e))
                .toList();

  int get itemCount => items.fold(0, (sum, it) => sum + it.quantity);
  bool get needsAcceptance => riderAcceptanceStatus == 'pending';
  bool get isActiveDelivery => status == 'out_for_delivery';
  bool get isDelivered => status == 'delivered';
  bool get isCash => paymentMethod?.toLowerCase() == 'cash';
}

class DispatchRequest {
  final int id;
  final int onlineOrderId;
  final String status;
  final int? acceptedRiderId;
  final String? acceptedAt;
  final DateTime? expiresAt;
  final String createdAt;
  final OnlineOrder order;

  DispatchRequest.fromJson(Map<String, dynamic> j)
      : id = _asInt(j['id']),
        onlineOrderId = _asInt(j['online_order_id']),
        status = _asStr(j['status'], 'pending'),
        acceptedRiderId = _asIntOrNull(j['accepted_rider_id']),
        acceptedAt = j['accepted_at']?.toString(),
        expiresAt = j['expires_at'] != null ? DateTime.tryParse(j['expires_at'].toString()) : null,
        createdAt = _asStr(j['created_at']),
        order = j['order'] is Map<String, dynamic>
            ? OnlineOrder.fromJson(j['order'] as Map<String, dynamic>)
            : OnlineOrder.fromJson(<String, dynamic>{});

  bool get isPending => status == 'pending';
  Duration? get remaining {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now());
  }
}

class PerformanceStats {
  final int totalDeliveries;
  final int totalEarnings;
  final int rating;
  final int totalReviews;
  final int todayDeliveries;
  final int thisWeekDeliveries;
  final int thisMonthDeliveries;

  PerformanceStats.fromJson(Map<String, dynamic> j)
      : totalDeliveries = _asInt(j['total_deliveries']),
        totalEarnings = _asInt(j['total_earnings']),
        rating = _asInt(j['rating']),
        totalReviews = _asInt(j['total_reviews']),
        todayDeliveries = _asInt(j['today_deliveries']),
        thisWeekDeliveries = _asInt(j['this_week_deliveries']),
        thisMonthDeliveries = _asInt(j['this_month_deliveries']);
}

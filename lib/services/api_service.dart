import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';
import '../models.dart';

class AuthExpiredException implements Exception {
  final String message;
  AuthExpiredException([this.message = 'Session expired']);
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final t = await token;
        if (t != null && t.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        return handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          await clearToken();
          sessionExpiredController.add(true);
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: DioExceptionType.badResponse,
              error: AuthExpiredException('Session expired. Please log in again.'),
            ),
          );
        }
        return handler.next(e);
      },
    ));
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';

  final StreamController<bool> sessionExpiredController =
      StreamController<bool>.broadcast();
  Stream<bool> get sessionExpired => sessionExpiredController.stream;

  // ---- Token handling ----
  Future<String?> get token async => _storage.read(key: _tokenKey);
  Future<void> saveToken(String t) async =>
      await _storage.write(key: _tokenKey, value: t);
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
  }

  Future<int?> get cachedUserId async {
    final v = await _storage.read(key: _userIdKey);
    return v == null ? null : int.tryParse(v);
  }

  Future<String?> get cachedUserName async =>
      _storage.read(key: _userNameKey);

  // ---- Auth ----
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('Login succeeded but the server returned no token.');
    }
    await saveToken(token);
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      await _storage.write(key: _userIdKey, value: '${user['id']}');
      await _storage.write(key: _userNameKey, value: '${user['name']}');
    }
    return data;
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> logout() async {
    final t = await token;
    if (t != null) {
      try {
        await _dio.post('/auth/logout');
      } catch (_) {}
    }
    await clearToken();
  }

  // ---- Profile ----
  Future<Map<String, dynamic>> getProfile() async =>
      (await _dio.get('/rider/profile')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> updatePersonalInfo(Map<String, dynamic> d) async =>
      (await _dio.put('/rider/personal-info', data: d)).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> getVehicle() async =>
      (await _dio.get('/rider/vehicle')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateVehicle(Map<String, dynamic> d) async =>
      (await _dio.put('/rider/vehicle', data: d)).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> getDocuments() async =>
      (await _dio.get('/rider/documents')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateDocuments(Map<String, dynamic> d) async =>
      (await _dio.put('/rider/documents', data: d)).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> getBankDetails() async =>
      (await _dio.get('/rider/bank-details')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateBankDetails(Map<String, dynamic> d) async =>
      (await _dio.put('/rider/bank-details', data: d)).data as Map<String, dynamic>;

  // ---- Profile image (per MOBILE_APP_NOTES.md §2) ----
  Future<Map<String, dynamic>> uploadProfileImage(File image) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        image.path,
        filename: image.path.split(RegExp(r'[/\\]')).last,
      ),
    });
    final res = await _dio.post('/rider/profile-image', data: form);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeProfileImage() async {
    final res = await _dio.post('/rider/profile-image', data: {'remove': true});
    return res.data as Map<String, dynamic>;
  }

  // ---- Performance & Reviews ----
  Future<Map<String, dynamic>> getPerformance() async =>
      (await _dio.get('/rider/performance')).data as Map<String, dynamic>;
  Future<Map<String, dynamic>> getReviews({int page = 1}) async =>
      (await _dio.get('/rider/reviews', queryParameters: {'page': page}))
          .data as Map<String, dynamic>;

  // ---- Location ----
  Future<void> updateLocation(double lat, double lng) async {
    await _dio.post('/rider/location', data: {'latitude': lat, 'longitude': lng});
  }

  // ---- Push notifications ----
  Future<void> updateDeviceToken(String token) async {
    try {
      await _dio.post('/rider/device-token', data: {
        'fcm_token': token,
        'device_type': 'android',
        'app_version': '1.0.0',
      });
    } catch (_) {
      // Non-fatal: retried on next login / token refresh.
    }
  }

  Future<void> removeDeviceToken(String token) async {
    try {
      await _dio.delete('/rider/device-token', data: {'fcm_token': token});
    } catch (_) {
      // Non-fatal: the row stays active if the server is unreachable.
    }
  }

  // ---- Orders ----
  Future<List<OnlineOrder>> getMyOrders() async {
    final res = await _dio.get('/rider/orders');
    return (res.data as List)
        .map((e) => OnlineOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OnlineOrder>> getAvailableOrders() async {
    final res = await _dio.get('/rider/orders/available');
    return (res.data as List)
        .map((e) => OnlineOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OnlineOrder> getOrder(int id) async {
    final res = await _dio.get('/rider/orders/$id');
    return OnlineOrder.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> acceptOrder(int id) async =>
      (await _dio.post('/rider/orders/$id/accept')).data as Map<String, dynamic>;

  Future<Map<String, dynamic>> rejectOrder(int id) async =>
      (await _dio.post('/rider/orders/$id/reject')).data as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateOrderStatus(
    int id,
    String status, {
    String? deliveryCode,
    String? notes,
  }) async =>
      (await _dio.put('/rider/orders/$id/status', data: {
        'status': status,
        'delivery_code': ?deliveryCode,
        'notes': ?notes,
      })).data as Map<String, dynamic>;

  // ---- Dispatch Requests (new delivery request flow) ----
  Future<List<DispatchRequest>> getDispatchRequests() async {
    final res = await _dio.get('/rider/dispatch-requests');
    return (res.data as List)
        .map((e) => DispatchRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> acceptDispatchRequest(int id) async =>
      (await _dio.post('/rider/dispatch-requests/$id/accept'))
          .data as Map<String, dynamic>;

  Future<Map<String, dynamic>> declineDispatchRequest(int id) async =>
      (await _dio.post('/rider/dispatch-requests/$id/decline'))
          .data as Map<String, dynamic>;

  // ---- Public ----
  Future<Map<String, dynamic>> getTermsPolicies() async =>
      (await _dio.get('/terms-policies')).data as Map<String, dynamic>;

  Future<Map<String, dynamic>> getRiderSupport() async =>
      (await _dio.get('/rider-support')).data as Map<String, dynamic>;

  // ---- Error helper ----
  static String errorMessage(Object? e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map) {
          for (final v in errors.values) {
            if (v is List && v.isNotEmpty) return v.first.toString();
          }
        }
        final message = data['message'];
        if (message != null && message.toString().isNotEmpty) {
          return message.toString();
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Connection error. Check your internet connection.';
      }
      return 'Something went wrong. Please try again.';
    }
    if (e is AuthExpiredException) return e.message;
    return 'Something went wrong. Please try again.';
  }
}

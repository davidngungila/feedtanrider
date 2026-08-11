import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/push_service.dart';

class RiderSession extends ChangeNotifier {
  final ApiService api = ApiService.instance;
  final LocationService location = LocationService();

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  Rider? _rider;
  Rider? get rider => _rider;

  PerformanceStats? _performance;
  PerformanceStats? get performance => _performance;

  bool _performanceFailed = false;
  bool get performanceFailed => _performanceFailed;

  List<DispatchRequest> _dispatchRequests = [];
  List<DispatchRequest> get dispatchRequests => _dispatchRequests;

  List<OnlineOrder> _myOrders = [];
  List<OnlineOrder> get myOrders => _myOrders;

  bool _busy = false;
  bool get busy => _busy;

  String? _lastError;
  String? get lastError => _lastError;

  Timer? _pollTimer;
  Timer? _tickTimer;

  // ---- Initialization (called from Splash) ----
  Future<bool> bootstrap() async {
    final token = await api.token;
    if (token == null || token.isEmpty) {
      _initialized = true;
      notifyListeners();
      return false;
    }
    try {
      await refreshProfile();
      _loggedIn = true;
      await _startBackgroundServices();
      unawaited(PushService.instance.registerToken());
    } catch (_) {
      // token invalid / network down -> stay on login
      _loggedIn = false;
    }
    _initialized = true;
    notifyListeners();
    return _loggedIn;
  }

  Future<void> signIn(String email, String password) async {
    await api.login(email, password);
    _loggedIn = true;
    await refreshProfile();
    await _startBackgroundServices();
    unawaited(PushService.instance.registerToken());
    notifyListeners();
  }

  Future<void> signOut() async {
    await _stopBackgroundServices();
    _loggedIn = false;
    _rider = null;
    _performance = null;
    _dispatchRequests = [];
    _myOrders = [];
    try {
      await api.logout();
    } catch (_) {
      // Best-effort server logout; the local session is cleared regardless.
    }
    notifyListeners();
  }

  // ---- Background services ----
  Future<void> _startBackgroundServices() async {
    await location.requestPermission();
    location.startReporting();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.pollingIntervalSeconds),
      (_) => silentRefresh(),
    );
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    await silentRefresh();
    await refreshPerformance();
  }

  Future<void> _stopBackgroundServices() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    location.stopReporting();
  }

  // ---- Data loading ----
  Future<void> refreshProfile() async {
    final data = await api.getProfile();
    final riderMap = data['rider'];
    if (riderMap is Map<String, dynamic>) {
      _rider = Rider.fromJson(riderMap);
    }
    notifyListeners();
  }

  Future<void> uploadProfileImage(File image) async {
    await api.uploadProfileImage(image);
    await refreshProfile();
  }

  Future<void> removeProfileImage() async {
    await api.removeProfileImage();
    await refreshProfile();
  }

  Future<void> refreshPerformance() async {
    _performanceFailed = false;
    notifyListeners();
    try {
      final data = await api.getPerformance();
      _performance = PerformanceStats.fromJson(data);
    } catch (_) {
      _performanceFailed = true;
    }
    notifyListeners();
  }

  Future<void> refreshDispatchRequests() async {
    _dispatchRequests = await api.getDispatchRequests();
    notifyListeners();
  }

  Future<void> refreshMyOrders() async {
    _myOrders = await api.getMyOrders();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await Future.wait([
        refreshProfile(),
        refreshPerformance(),
        refreshDispatchRequests(),
        refreshMyOrders(),
      ]);
    } catch (e) {
      _lastError = ApiService.errorMessage(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> silentRefresh() async {
    try {
      await Future.wait([
        refreshDispatchRequests(),
        refreshMyOrders(),
      ]);
      _lastError = null;
    } catch (e) {
      _lastError = ApiService.errorMessage(e);
    }
    notifyListeners();
  }

  void clearLastError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  // ---- Order actions ----
  Future<Map<String, dynamic>> acceptDispatchRequest(DispatchRequest r) async {
    final res = await api.acceptDispatchRequest(r.id);
    await refreshMyOrders();
    await refreshDispatchRequests();
    return res;
  }

  Future<Map<String, dynamic>> declineDispatchRequest(DispatchRequest r) async {
    final res = await api.declineDispatchRequest(r.id);
    await refreshDispatchRequests();
    return res;
  }

  Future<Map<String, dynamic>> acceptOrder(OnlineOrder o) async {
    final res = await api.acceptOrder(o.id);
    await refreshMyOrders();
    await refreshDispatchRequests();
    return res;
  }

  Future<Map<String, dynamic>> rejectOrder(OnlineOrder o) async {
    final res = await api.rejectOrder(o.id);
    await refreshMyOrders();
    return res;
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    OnlineOrder o,
    String status, {
    String? deliveryCode,
    String? notes,
  }) async {
    final res = await api.updateOrderStatus(
      o.id,
      status,
      deliveryCode: deliveryCode,
      notes: notes,
    );
    await refreshMyOrders();
    return res;
  }

  // ---- Derived lists ----
  List<OnlineOrder> get pendingOrders =>
      _myOrders.where((o) => o.needsAcceptance).toList();

  List<OnlineOrder> get activeOrders => _myOrders
      .where((o) => !o.isDelivered && o.status != 'cancelled')
      .toList();

  List<OnlineOrder> get deliveryOrders =>
      _myOrders.where((o) => o.isDelivered).toList();

  List<OnlineOrder> get completedOrders =>
      _myOrders.where((o) => o.isDelivered || o.status == 'cancelled').toList();

  @override
  void dispose() {
    _stopBackgroundServices();
    super.dispose();
  }
}

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config.dart';
import 'api_service.dart';

class LocationService {
  StreamSubscription<Position>? _sub;
  bool _reporting = false;
  bool _permissionGranted = false;

  bool get reporting => _reporting;

  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    _permissionGranted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    return _permissionGranted;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void startReporting() {
    if (_reporting) return;
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) async {
      await _report(pos.latitude, pos.longitude);
    });
    _reporting = true;
    _periodicTimer = Timer.periodic(
      Duration(seconds: AppConfig.locationReportSeconds),
      (_) async {
        final pos = await getCurrentPosition();
        if (pos != null) await _report(pos.latitude, pos.longitude);
      },
    );
  }

  Timer? _periodicTimer;

  Future<void> _report(double lat, double lng) async {
    try {
      await ApiService.instance.updateLocation(lat, lng);
    } catch (_) {
      // offline - retry on next tick
    }
  }

  void stopReporting() {
    _reporting = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _sub?.cancel();
    _sub = null;
  }
}

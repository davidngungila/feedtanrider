import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models.dart';
import '../theme.dart';

/// Full-screen live navigation: rider position, OSRM route from the store to
/// the customer, a next-maneuver instruction card and a live distance/ETA.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.order});

  final OnlineOrder order;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  final Dio _osrm = Dio(BaseOptions(
    baseUrl: 'https://router.project-osrm.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));

  static const LatLng _store = LatLng(AppConfig.storeLat, AppConfig.storeLng);

  LatLng? _rider;
  List<LatLng>? _route;
  String _instruction = 'Waiting for your location…';
  double _routeDistanceM = 0;
  bool _fetching = false;
  StreamSubscription<Position>? _sub;

  OnlineOrder get _order => widget.order;

  LatLng? get _dest {
    final lat = _order.deliveryLatitude;
    final lng = _order.deliveryLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  bool get _arrived =>
      _rider != null && _dest != null && _meters(_rider!, _dest!) < 50;

  double _meters(LatLng a, LatLng b) => const Distance().distance(a, b);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _instruction = 'Location permission denied');
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (mounted && last != null) {
        setState(() => _rider = LatLng(last.latitude, last.longitude));
        _fetchRoute();
      }
    } catch (_) {
      // Permission dialog failures shouldn't block the map.
    }
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final now = LatLng(pos.latitude, pos.longitude);
      final prev = _rider;
      setState(() => _rider = now);
      if (prev == null || _meters(prev, now) > 300 || _route == null) {
        _fetchRoute();
      }
      if (prev == null || _meters(prev, now) > 40) {
        _mapController.move(now, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _fetchRoute() async {
    final pos = _rider;
    final dest = _dest;
    if (pos == null || dest == null || _fetching) return;
    _fetching = true;
    try {
      final coords = [_store, pos, dest]
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final res = await _osrm.get(
        '/route/v1/driving/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      );
      final routes = ((res.data as Map<String, dynamic>)['routes'] as List?) ?? [];
      if (routes.isEmpty || !mounted) return;
      final route = routes.first as Map<String, dynamic>;
      final coordsJson =
          (route['geometry'] as Map?)?['coordinates'] as List? ?? [];
      final points = coordsJson.map((c) {
        final l = c as List;
        return LatLng((l[1] as num).toDouble(), (l[0] as num).toDouble());
      }).toList();
      setState(() {
        _route = points;
        _routeDistanceM = (route['distance'] as num? ?? 0).toDouble();
        _instruction = _nextInstruction(route);
      });
    } catch (_) {
      // Fall back to a straight line so the rider can still navigate.
      if (mounted && _route == null) {
        setState(() {
          _route = [pos, dest];
          _routeDistanceM = _meters(pos, dest);
          _instruction = 'Directions unavailable — head straight to the customer';
        });
      }
    } finally {
      _fetching = false;
    }
  }

  String _nextInstruction(Map<String, dynamic> route) {
    final legs = route['legs'] as List? ?? [];
    final steps = <Map<String, dynamic>>[];
    for (final leg in legs) {
      for (final s in (leg['steps'] as List? ?? [])) {
        steps.add(s as Map<String, dynamic>);
      }
    }
    if (steps.isEmpty) return 'Drive to the customer';
    final rider = _rider;
    Map<String, dynamic>? next;
    for (final s in steps) {
      final m = s['maneuver'];
      if (m is! Map) continue;
      final loc = m['location'];
      if (loc is! List || loc.length < 2) continue;
      final d = rider == null
          ? double.infinity
          : _meters(
              rider,
              LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
            );
      if (d > 50) {
        next = s;
        break;
      }
    }
    next ??= steps.first;
    final m = (next['maneuver'] as Map? ?? {});
    final type = (m['type'] ?? '').toString();
    final modifier = (m['modifier'] ?? '').toString();
    final name = (next['name'] ?? '').toString();
    final street = name.isEmpty ? '' : ' on $name';
    switch (type) {
      case 'depart':
        return 'Head ${_dir(modifier)}$street';
      case 'arrive':
        return 'Arrived at the customer';
      case 'turn':
        return 'Turn ${_dir(modifier)}$street';
      case 'continue':
        return 'Continue straight$street';
      case 'merge':
        return 'Merge ${_dir(modifier)}$street';
      case 'roundabout':
      case 'rotary':
        return 'Enter the roundabout and take the ${modifier.isEmpty ? 'next' : modifier} exit';
      case 'fork':
        return 'Keep ${_dir(modifier)}';
      case 'exit':
        return 'Take the exit$street';
      default:
        return name.isEmpty ? 'Continue' : 'Continue$street';
    }
  }

  String _dir(String modifier) {
    switch (modifier) {
      case 'left':
        return 'left';
      case 'right':
        return 'right';
      case 'slight left':
        return 'slightly left';
      case 'slight right':
        return 'slightly right';
      case 'sharp left':
        return 'sharp left';
      case 'sharp right':
        return 'sharp right';
      case 'straight':
        return 'straight';
      case 'uturn':
        return 'a U-turn';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _osrm.close();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dest = _dest;
    final rider = _rider;
    final distKm = _routeDistanceM > 0
        ? _routeDistanceM / 1000
        : (rider != null && dest != null ? _meters(rider, dest) / 1000 : 0.0);
    final etaMin = (distKm / 25 * 60).round().clamp(1, 999).toInt();
    return Scaffold(
      backgroundColor: FT.bg,
      body: GlassBackground(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: rider ?? _store,
                initialZoom: 15,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.feedtanstore.rider',
                ),
                if (_route != null && _route!.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route!,
                        color: FT.green600,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (dest != null)
                      Marker(
                        point: dest,
                        width: 34,
                        height: 34,
                        child: _pin(Icons.location_on_rounded, FT.danger),
                      ),
                    Marker(
                      point: _store,
                      width: 34,
                      height: 34,
                      child: _pin(Icons.storefront_rounded, FT.green700),
                    ),
                    if (rider != null)
                      Marker(
                        point: rider,
                        width: 34,
                        height: 34,
                        child: _pin(
                          Icons.delivery_dining_rounded,
                          FT.goldDark,
                          ring: FT.gold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _instructionCard(),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _bottomCard(distKm, etaMin),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instructionCard() {
    final arrived = _arrived;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: glassCardDecoration(
        color: arrived ? FT.green100 : FT.white,
      ),
      child: Row(
        children: [
          Icon(
            arrived ? Icons.check_circle_rounded : Icons.navigation_rounded,
            color: arrived ? FT.green700 : FT.green700,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              arrived ? 'You have arrived at the customer' : _instruction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: arrived ? FT.green800 : FT.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomCard(double distKm, int etaMin) {
    final dest = _dest;
    final rider = _rider;
    final hasCoords = dest != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasCoords)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${distKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: FT.ink,
                      ),
                    ),
                    Text(
                      'to the customer',
                      style: const TextStyle(fontSize: 11.5, color: FT.inkSoft),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '~$etaMin min',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: FT.green700,
                      ),
                    ),
                    Text(
                      'est. on the move',
                      style: const TextStyle(fontSize: 11.5, color: FT.inkSoft),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              rider == null
                  ? 'Waiting for your location…'
                  : 'No delivery coordinates for this order',
              style: const TextStyle(fontSize: 13, color: FT.inkSoft),
            ),
          if (hasCoords) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 15, color: FT.inkSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_order.customerName} · ${_order.deliveryAddress}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: FT.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FTButton(
              label: 'Stop navigation',
              color: FT.ink,
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin(IconData icon, Color color, {Color? ring}) {
    return Center(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FT.white,
          border: Border.all(color: ring ?? color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

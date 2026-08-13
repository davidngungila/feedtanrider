import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/app_errors.dart';
import '../state/session.dart';
import '../theme.dart';
import 'navigation_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<OnlineOrder> _future;
  LatLng? _riderPosition;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getOrder(widget.orderId);
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (mounted) setState(() => _riderPosition = LatLng(pos.latitude, pos.longitude));
  }

  void _reload() {
    setState(() => _future = ApiService.instance.getOrder(widget.orderId));
  }

  Future<void> _openNavigation(OnlineOrder o) async {
    final lat = o.deliveryLatitude;
    final lng = o.deliveryLongitude;
    if (lat == null || lng == null) {
      showFTSnack(context, 'No delivery coordinates available for this order');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NavigationScreen(order: o)),
    );
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = 'tel:${phone.replaceAll(' ', '')}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: GlassBackground(
        child: FutureBuilder<OnlineOrder>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: FT.green700));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44, color: FT.inkSoft),
                    const SizedBox(height: 12),
                    Text(
                      ApiService.errorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: FT.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    FTButton(label: 'Retry', onTap: _reload, icon: Icons.refresh_rounded),
                  ],
                ),
              ),
            );
          }
          final o = snapshot.data!;
          return _content(context, o);
        },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, OnlineOrder o) {
    return RefreshIndicator(
      color: FT.green700,
      backgroundColor: FT.white,
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.paddingOf(context).bottom + 12,
        ),
        children: [
          _statusBanner(o),
          const SizedBox(height: 14),
          _customerCard(o),
          const SizedBox(height: 14),
          _mapCard(o),
          const SizedBox(height: 14),
          _itemsCard(o),
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _notesCard(o.notes!),
          ],
          if (o.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            _timelineCard(o),
          ],
          const SizedBox(height: 20),
          if (o.isActiveDelivery) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openNavigation(o),
                icon: const Icon(Icons.navigation_rounded, size: 17, color: FT.green700),
                label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.w800, color: FT.green700)),
                style: ftGlassOutlinedStyle(FT.green700),
              ),
            ),
            const SizedBox(height: 10),
            FTButton(
              label: 'Mark as Delivered',
              icon: Icons.check_circle_rounded,
              color: FT.gold,
              onTap: () => _markDelivered(o),
            ),
          ] else if (o.needsAcceptance)
            FTButton(
              label: 'Accept Order',
              icon: Icons.check_circle_rounded,
              onTap: () => _accept(o),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _accept(OnlineOrder o) async {
    try {
      await context.read<RiderSession>().acceptOrder(o);
      if (mounted) {
        showFTSnack(context, 'Order accepted', background: FT.green700);
        _reload();
      }
    } catch (e) {
      if (mounted) showFTError(context, e);
    }
  }

  Future<void> _markDelivered(OnlineOrder o) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeliveryCodeDialog(order: o),
    );
    if (done != true || !mounted) return;
    showFTSnack(context, 'Delivery complete', background: FT.green700);
    _reload();
  }

  Widget _statusBanner(OnlineOrder o) {
    final (label, bg, fg) = _statusColors(o.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: fg)),
                const SizedBox(height: 2),
                Text(
                  '${o.orderNumber} · ${o.paymentMethod ?? 'N/A'}',
                  style: TextStyle(fontSize: 11.5, color: fg.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Text(fmtTZS(o.total), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
        ],
      ),
    );
  }

  (String, Color, Color) _statusColors(String status) {
    switch (status) {
      case 'confirmed':
      case 'preparing':
        return ('Preparing', FT.goldLight, FT.goldDark);
      case 'ready':
        return ('Ready', FT.green100, FT.green700);
      case 'out_for_delivery':
        return ('Out for delivery', FT.green50, FT.green700);
      case 'delivered':
        return ('Delivered', FT.green100, FT.green800);
      case 'cancelled':
        return ('Cancelled', const Color(0xFFFDECEC), FT.danger);
      default:
        return (status.toUpperCase(), FT.green50, FT.green700);
    }
  }

  Widget _customerCard(OnlineOrder o) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: FT.green50, shape: BoxShape.circle),
            child: Icon(Icons.person_rounded, color: FT.green700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customer', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: FT.inkSoft)),
                const SizedBox(height: 2),
                Text(o.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: FT.ink)),
                Text(o.customerPhone, style: const TextStyle(fontSize: 12, color: FT.inkSoft)),
                const SizedBox(height: 4),
                Text(
                  o.deliveryAddress,
                  style: const TextStyle(fontSize: 11.5, color: FT.inkSoft, height: 1.3),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _callCustomer(o.customerPhone),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: FT.green700, shape: BoxShape.circle),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCard(OnlineOrder o) {
    return FTCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: OrderMapView(order: o, riderPosition: _riderPosition),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.store_rounded, size: 15, color: FT.green700),
                const SizedBox(width: 7),
                const Expanded(child: Text('Feedtan Store (pickup)', style: TextStyle(fontSize: 11.5, color: FT.inkSoft))),
                Text(
                  o.deliveryLatitude != null ? '${o.deliveryLatitude!.toStringAsFixed(4)}, ${o.deliveryLongitude!.toStringAsFixed(4)}' : 'No coords',
                  style: const TextStyle(fontSize: 10.5, color: FT.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(OnlineOrder o) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FT.ink)),
          const SizedBox(height: 12),
          if (o.items.isEmpty)
            const Text('No items', style: TextStyle(fontSize: 12, color: FT.inkSoft))
          else
            ...o.items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: FT.green50, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.shopping_bag_rounded, size: 17, color: FT.green700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.productName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: FT.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${it.quantity} × ${fmtTZS(it.price)}', style: const TextStyle(fontSize: 11, color: FT.inkSoft)),
                        ],
                      ),
                    ),
                    Text(fmtTZS(it.total), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: FT.ink)),
                  ],
                ),
              ),
            ),
          const Divider(height: 18),
          _sumRow('Subtotal', fmtTZS(o.subtotal)),
          if (o.discount > 0) _sumRow('Discount', '-${fmtTZS(o.discount)}'),
          _sumRow('Delivery Fee', fmtTZS(o.deliveryFee)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: FT.ink)),
              const Spacer(),
              Text(fmtTZS(o.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: FT.green700)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: o.isCash ? FT.goldLight : FT.green50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(o.isCash ? Icons.payments_rounded : Icons.check_circle_rounded, size: 18, color: o.isCash ? FT.goldDark : FT.green700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    o.isCash ? 'Collect ${fmtTZS(o.total)} from the customer.' : 'Payment method: ${o.paymentMethod} ✓',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: o.isCash ? FT.goldDark : FT.green700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesCard(String notes) {
    return FTCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes_rounded, color: FT.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: FT.inkSoft)),
                const SizedBox(height: 4),
                Text(notes, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FT.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard(OnlineOrder o) {
    final history = o.statusHistory.reversed.toList();
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Timeline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FT.ink)),
          const SizedBox(height: 12),
          ...List.generate(history.length, (i) {
            final h = history[i];
            final isLast = i == history.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(color: FT.green700, shape: BoxShape.circle),
                    ),
                    if (!isLast)
                      Container(width: 2, height: 30, color: FT.line),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.status, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: FT.ink)),
                        if (h.notes != null && h.notes!.isNotEmpty)
                          Text(h.notes!, style: const TextStyle(fontSize: 11, color: FT.inkSoft, height: 1.3)),
                        Text(formatDate(h.createdAt), style: const TextStyle(fontSize: 10, color: FT.inkSoft)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: FT.inkSoft)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: FT.ink)),
        ],
      ),
    );
  }
}

class _DeliveryCodeDialog extends StatefulWidget {
  final OnlineOrder order;
  const _DeliveryCodeDialog({required this.order});

  @override
  State<_DeliveryCodeDialog> createState() => _DeliveryCodeDialogState();
}

class _DeliveryCodeDialogState extends State<_DeliveryCodeDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final v = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(v)) {
      setState(() => _error = 'Invalid delivery code. Please enter the correct 4-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<RiderSession>().updateOrderStatus(
            widget.order,
            'delivered',
            deliveryCode: v,
            notes: 'Delivered successfully',
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showFTError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: FTGlassDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.password_rounded, color: FT.green700, size: 24),
                SizedBox(width: 8),
                Text('Delivery Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Ask the customer for the 4-digit delivery code for ${widget.order.orderNumber}.',
              style: const TextStyle(fontSize: 13, color: FT.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              enabled: !_loading,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8),
              decoration: ftInputDecoration(
                label: 'Delivery code',
                icon: Icons.pin_rounded,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 11, color: FT.danger, height: 1.35),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: FT.inkSoft, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: ftGlassFilledStyle(FT.green700),
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & Complete', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderMapView extends StatelessWidget {
  final OnlineOrder order;
  final LatLng? riderPosition;
  const OrderMapView({super.key, required this.order, this.riderPosition});

  @override
  Widget build(BuildContext context) {
    final store = LatLng(AppConfig.storeLat, AppConfig.storeLng);
    final destination = (order.deliveryLatitude != null && order.deliveryLongitude != null)
        ? LatLng(order.deliveryLatitude!, order.deliveryLongitude!)
        : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: riderPosition ?? store,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.feedtanstore.rider',
          ),
          MarkerLayer(
            markers: [
              if (riderPosition != null)
                Marker(
                  point: riderPosition!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 36),
                ),
              Marker(
                point: store,
                width: 32,
                height: 32,
                child: const Icon(Icons.store, color: Colors.green, size: 30),
              ),
              if (destination != null)
                Marker(
                  point: destination,
                  width: 32,
                  height: 32,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 34),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

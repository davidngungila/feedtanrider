import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/app_errors.dart';
import '../state/session.dart';
import '../theme.dart';
import 'order_detail_screen.dart';

class AvailableScreen extends StatefulWidget {
  const AvailableScreen({super.key});

  @override
  State<AvailableScreen> createState() => _AvailableScreenState();
}

class _AvailableScreenState extends State<AvailableScreen> {
  Timer? _countdown;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _accept(RiderSession session, DispatchRequest r) async {
    if (_accepting) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Accept this delivery?',
      message: 'Order ${r.order.orderNumber} for ${r.order.customerName}. Total ${fmtTZS(r.order.total)}. First to accept gets the order.',
      confirmLabel: 'Accept',
    );
    if (!confirmed) return;
    setState(() => _accepting = true);
    try {
      await session.acceptDispatchRequest(r);
      if (!mounted) return;
      showFTSnack(context, 'Order assigned to you', background: FT.green700);
      final openNav = await confirmDialog(
        context,
        title: 'Start navigation?',
        message: 'Open turn-by-turn directions to the customer?',
        confirmLabel: 'Navigate',
      );
      if (openNav && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: r.order.id)),
        );
      }
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline(RiderSession session, DispatchRequest r) async {
    try {
      await session.declineDispatchRequest(r);
      if (mounted) showFTSnack(context, 'Dispatch request declined');
    } catch (e) {
      if (mounted) showFTError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RiderSession>(
      builder: (context, session, _) {
        final requests = session.dispatchRequests;
        final actionable = requests
            .where((r) => !(r.remaining != null && r.remaining!.isNegative))
            .length;
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Deliveries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: FT.ink)),
                          const SizedBox(height: 3),
                          Text(
                            '${requests.length} pending · new requests appear live',
                            style: const TextStyle(fontSize: 12, color: FT.inkSoft),
                          ),
                          if (actionable > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: FT.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.notifications_active_rounded, size: 14, color: FT.danger),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$actionable need your response',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: FT.danger),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: FT.green700,
                  backgroundColor: FT.white,
                  onRefresh: () async {
                    try {
                      await session.refreshDispatchRequests();
                      session.clearLastError();
                    } catch (e) {
                      if (context.mounted) {
                        showFTError(context, e);
                      }
                    }
                  },
                  child: requests.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: ftNavClearance(context)),
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: emptyState(
                                Icons.radio_button_checked_rounded,
                                'No deliveries right now',
                                'New dispatch requests appear here as soon as the shop sends them.',
                              ),
                            ),
                            if (session.lastError != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.wifi_off_rounded, size: 14, color: FT.danger),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          session.lastError!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11.5, color: FT.danger),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(20, 6, 20, ftNavClearance(context)),
                          itemCount: requests.length,
                          itemBuilder: (_, i) => _requestCard(context, session, requests[i]),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _requestCard(BuildContext context, RiderSession session, DispatchRequest r) {
    final o = r.order;
    final remaining = r.remaining;
    final expired = remaining != null && remaining.isNegative;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FTCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: FT.gold, borderRadius: BorderRadius.circular(8)),
                  child: const Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(o.orderNumber, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: FT.ink)),
                ),
                if (remaining != null)
                  _expiryChip(remaining, expired),
              ],
            ),
            const SizedBox(height: 12),
            _row(Icons.person_rounded, '${o.customerName} · ${o.customerPhone}'),
            const SizedBox(height: 6),
            _row(Icons.location_on_rounded, o.deliveryAddress.isEmpty ? 'Address not set' : o.deliveryAddress),
            const SizedBox(height: 6),
            _row(Icons.shopping_bag_rounded, '${o.itemCount} items · ${o.paymentMethod ?? 'N/A'}'),
            const SizedBox(height: 6),
            _row(Icons.payments_rounded, 'Subtotal ${fmtTZS(o.subtotal)} + Delivery ${fmtTZS(o.deliveryFee)}', color: FT.inkSoft),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FT.inkSoft)),
                Text(fmtTZS(o.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: FT.green700)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: expired || _accepting
                        ? null
                        : () => _decline(session, r),
                    style: ftGlassOutlinedStyle(FT.inkSoft),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: expired || _accepting ? null : () => _accept(session, r),
                    icon: _accepting
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(_accepting ? 'Accepting...' : 'Accept Delivery', style: const TextStyle(fontSize: 12.5)),
                    style: ftGlassFilledStyle(FT.green700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiryChip(Duration remaining, bool expired) {
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    final text = expired ? 'Expired' : '${mins}m ${secs.toString().padLeft(2, '0')}s';
    final color = expired ? FT.inkSoft : (mins < 5 ? FT.danger : FT.goldDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, {Color color = FT.inkSoft}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color))),
      ],
    );
  }
}

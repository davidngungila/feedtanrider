import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/app_errors.dart';
import '../state/session.dart';
import '../state/tabs.dart';
import '../theme.dart';
import 'order_detail_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RiderSession>(
      builder: (context, session, _) {
        return DefaultTabController(
          length: 2,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: FT.ink)),
                      const SizedBox(height: 3),
                      Text(
                        '${session.myOrders.length} assigned deliveries',
                        style: const TextStyle(fontSize: 12, color: FT.inkSoft),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _OrderTabs(session: session),
                ),
                const SizedBox(height: 4),
                Expanded(child: TabBarView(children: [
                  _ActiveTab(),
                  _DeliveryTab(),
                ])),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderTabs extends StatelessWidget {
  final RiderSession session;
  const _OrderTabs({required this.session});

  @override
  Widget build(BuildContext context) {
    final activeCount = session.activeOrders.length;
    final deliveryCount = session.deliveryOrders.length;
    
    return Container(
      decoration: BoxDecoration(
        color: FT.green50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: FT.green700,
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: FT.inkSoft,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Active'),
                if (activeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Delivery'),
                if (deliveryCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$deliveryCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTab extends StatelessWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<RiderSession>();
    final orders = session.activeOrders;
    return _OrderList(
      orders: orders,
      emptyIcon: Icons.directions_bike_rounded,
      emptyTitle: 'No active orders',
      emptyDesc: 'Accepted orders ready for pickup will appear here.',
      itemBuilder: (o) => _ActiveCard(order: o),
      refresh: session.refreshMyOrders,
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final OnlineOrder order;
  const _DeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.orderNumber, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: FT.ink)),
              ),
              _statusChip('Out for delivery', FT.green700, FT.green50),
            ],
          ),
          const SizedBox(height: 10),
          _row(Icons.person_rounded, '${order.customerName} · ${order.customerPhone}'),
          const SizedBox(height: 6),
          _row(Icons.location_on_rounded, order.deliveryAddress),
          const SizedBox(height: 6),
          _row(Icons.payments_rounded, '${fmtTZS(order.total)} · ${order.paymentMethod ?? 'N/A'}', color: FT.inkSoft),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
              ),
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('View & Navigate', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ftGlassFilledStyle(FT.green700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<RiderSession>();
    final orders = session.deliveryOrders;
    return _OrderList(
      orders: orders,
      emptyIcon: Icons.delivery_dining_rounded,
      emptyTitle: 'No deliveries in progress',
      emptyDesc: 'Orders out for delivery appear here with live navigation.',
      itemBuilder: (o) => _DeliveryCard(order: o),
      refresh: session.refreshMyOrders,
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OnlineOrder> orders;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDesc;
  final Widget Function(OnlineOrder) itemBuilder;
  final Future<void> Function() refresh;

  const _OrderList({
    required this.orders,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDesc,
    required this.itemBuilder,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: ftNavClearance(context)),
          children: [
            const SizedBox(height: 100),
            Center(child: emptyState(emptyIcon, emptyTitle, emptyDesc)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: FT.green700,
      backgroundColor: FT.white,
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 12, 20, ftNavClearance(context)),
        itemCount: orders.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: itemBuilder(orders[i]),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final OnlineOrder order;
  const _PendingCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final session = context.read<RiderSession>();
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.orderNumber, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: FT.ink)),
              ),
              _statusChip('Awaiting acceptance', FT.goldDark, FT.goldLight),
            ],
          ),
          const SizedBox(height: 10),
          _row(Icons.person_rounded, order.customerName),
          const SizedBox(height: 6),
          _row(Icons.location_on_rounded, order.deliveryAddress),
          const SizedBox(height: 6),
          _row(Icons.payments_rounded, '${fmtTZS(order.total)} · ${order.paymentMethod ?? 'N/A'}', color: FT.inkSoft),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await session.rejectOrder(order);
                      if (context.mounted) showFTSnack(context, 'Order rejected');
                    } catch (e) {
                      if (context.mounted) showFTError(context, e);
                    }
                  },
                  style: ftGlassOutlinedStyle(FT.inkSoft),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await session.acceptOrder(order);
                      showFTSnackMessenger(
                        messenger,
                        'Order accepted',
                        background: FT.green700,
                      );
                      shellTab.value = 2;
                    } catch (e) {
                      if (context.mounted) showFTError(context, e);
                    }
                  },
                  style: ftGlassFilledStyle(FT.green700),
                  child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final OnlineOrder order;
  const _ActiveCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final session = context.read<RiderSession>();
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.orderNumber, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: FT.ink)),
              ),
              _statusChip('Accepted', FT.green700, FT.green50),
            ],
          ),
          const SizedBox(height: 10),
          _row(Icons.person_rounded, '${order.customerName} · ${order.customerPhone}'),
          const SizedBox(height: 6),
          _row(Icons.location_on_rounded, order.deliveryAddress),
          const SizedBox(height: 6),
          _row(Icons.payments_rounded, '${fmtTZS(order.total)} · ${order.paymentMethod ?? 'N/A'}', color: FT.inkSoft),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await session.updateOrderStatus(order, 'out_for_delivery');
                  if (context.mounted) showFTSnack(context, 'Order marked as out for delivery', background: FT.green700);
                } catch (e) {
                  if (context.mounted) showFTError(context, e);
                }
              },
              icon: const Icon(Icons.directions_bike_rounded, size: 16),
              label: const Text('Start Delivery', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ftGlassFilledStyle(FT.green700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final OnlineOrder order;
  const _CompletedCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled';
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cancelled ? FT.goldLight : FT.green50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              cancelled ? Icons.cancel_rounded : Icons.check_circle_rounded,
              size: 20,
              color: cancelled ? FT.goldDark : FT.green700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FT.ink)),
                const SizedBox(height: 3),
                Text(
                  '${order.customerName} · ${order.isDelivered ? 'Delivered' : 'Cancelled'}',
                  style: const TextStyle(fontSize: 11.5, color: FT.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            order.isDelivered ? '+${fmtTZS(order.deliveryFee)}' : fmtTZS(order.total),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: cancelled ? FT.inkSoft : FT.green700,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _statusChip(String label, Color fg, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
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

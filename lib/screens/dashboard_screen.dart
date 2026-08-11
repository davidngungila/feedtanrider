import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/app_errors.dart';
import '../state/session.dart';
import '../state/tabs.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RiderSession>(
      builder: (context, session, _) {
        final rider = session.rider;
        final perf = session.performance;
        final pending = session.pendingOrders;
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: FT.green700,
            backgroundColor: FT.white,
            onRefresh: () => session.refreshAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 14, 20, ftNavClearance(context)),
              children: [
                _header(context, rider),
                const SizedBox(height: 18),
                _heroCard(context, session),
                const SizedBox(height: 24),
                sectionTitle('Quick Actions'),
                _quickActions(context),
                const SizedBox(height: 24),
                sectionTitle('Performance'),
                if (perf == null)
                  session.performanceFailed
                      ? _performanceError(context, session)
                      : const FTCard(
                          child: SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: FT.green700)),
                          ),
                        )
                else
                  _performanceCard(perf),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  sectionTitle('Needs Your Action'),
                  ...pending.take(3).map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _pendingTile(context, session, o),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Rider? rider) {
    final name = rider?.name ?? 'Rider';
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(color: FT.goldLight, shape: BoxShape.circle),
          child: const Icon(Icons.two_wheeler_rounded, color: FT.goldDark, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greeting()},',
                style: const TextStyle(fontSize: 12, color: FT.inkSoft, fontWeight: FontWeight.w600),
              ),
              Text(
                name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: FT.ink),
              ),
            ],
          ),
        ),
        if (rider != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: rider.isActive ? FT.green50 : FT.goldLight,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: rider.isActive ? FT.green600 : FT.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  rider.isActive ? 'Online' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: rider.isActive ? FT.green700 : FT.goldDark,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _heroCard(BuildContext context, RiderSession session) {
    final perf = session.performance;
    final today = perf?.todayDeliveries ?? 0;
    final earnings = perf?.totalEarnings ?? 0;
    final rating = perf?.rating ?? 0;
    final reviews = perf?.totalReviews ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: FT.goldLight,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 20, color: FT.goldDark),
              ),
              const SizedBox(width: 10),
              const Text('Total Earnings', style: TextStyle(color: FT.inkSoft, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fmtTZS(earnings),
            style: const TextStyle(color: FT.ink, fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _chip(icon: Icons.local_shipping_rounded, color: FT.green700, value: '$today', label: 'Today')),
              const SizedBox(width: 10),
              Expanded(child: _chip(icon: Icons.star_rounded, color: FT.goldDark, value: '$rating ★', label: '$reviews reviews')),
              const SizedBox(width: 10),
              Expanded(child: _chip(icon: Icons.timeline_rounded, color: FT.green700, value: '${perf?.thisMonthDeliveries ?? 0}', label: 'This Month')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({required IconData icon, required Color color, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: FT.ink, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: FT.inkSoft, fontSize: 9.5)),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _actionCard(context, Icons.notifications_rounded, 'Available', 'Dispatch requests', 1)),
        const SizedBox(width: 10),
        Expanded(child: _actionCard(context, Icons.receipt_long_rounded, 'My Orders', 'Assigned deliveries', 2)),
        const SizedBox(width: 10),
        Expanded(child: _actionCard(context, Icons.person_rounded, 'Profile', 'View & edit', 3)),
      ],
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String label, String sub, int tab) {
    return FTCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      onTap: () => shellTab.value = tab,
      child: Column(
        children: [
          Icon(icon, size: 20, color: FT.green700),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: FT.ink)),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: FT.inkSoft)),
        ],
      ),
    );
  }

  Widget _performanceError(BuildContext context, RiderSession session) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: FT.inkSoft),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Could not load performance',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: FT.inkSoft),
            ),
          ),
          FTButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onTap: () => session.refreshPerformance(),
          ),
        ],
      ),
    );
  }

  Widget _performanceCard(PerformanceStats perf) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _perfItem('${perf.todayDeliveries}', 'Today')),
          Container(width: 1, height: 40, color: FT.line),
          Expanded(child: _perfItem('${perf.thisWeekDeliveries}', 'This Week')),
          Container(width: 1, height: 40, color: FT.line),
          Expanded(child: _perfItem('${perf.thisMonthDeliveries}', 'This Month')),
          Container(width: 1, height: 40, color: FT.line),
          Expanded(child: _perfItem('${perf.totalDeliveries}', 'All Time')),
        ],
      ),
    );
  }

  Widget _perfItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: FT.green700)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 10.5, color: FT.inkSoft, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _pendingTile(BuildContext context, RiderSession session, OnlineOrder o) {
    return FTCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: FT.goldLight, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, color: FT.goldDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.orderNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FT.ink)),
                const SizedBox(height: 2),
                Text('${o.customerName} · ${fmtTZS(o.total)}', style: const TextStyle(fontSize: 11.5, color: FT.inkSoft)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await session.acceptOrder(o);
                if (context.mounted) {
                  showFTSnack(context, 'Order accepted', background: FT.green700);
                }
              } catch (e) {
                if (context.mounted) showFTError(context, e);
              }
            },
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w800, color: FT.green700)),
          ),
        ],
      ),
    );
  }
}

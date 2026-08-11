import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/session.dart';
import '../theme.dart';
import '../state/tabs.dart';
import 'edit_screens.dart';
import 'reviews_screen.dart';
import 'support_screen.dart';
import 'terms_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RiderSession>(
      builder: (context, session, _) {
        final rider = session.rider;
        if (rider == null) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: FT.green700)),
          );
        }
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: FT.green700,
            backgroundColor: FT.white,
            onRefresh: session.refreshProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 20, 20, ftNavClearance(context)),
              children: [
                _header(rider),
                const SizedBox(height: 22),
                _vehicleCard(rider),
                const SizedBox(height: 24),
                const Text('ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FT.inkSoft, letterSpacing: 1)),
                const SizedBox(height: 10),
                _tile(context, Icons.person_rounded, 'Personal Information', onTap: () => _open(context, const PersonalInfoScreen())),
                _tile(context, Icons.two_wheeler_rounded, 'Vehicle Details', onTap: () => _open(context, const VehicleScreen())),
                _tile(context, Icons.badge_outlined, 'Documents & License', onTap: () => _open(context, const DocumentsScreen())),
                _tile(context, Icons.account_balance_rounded, 'Bank & Mobile Money', onTap: () => _open(context, const BankScreen())),
                _tile(context, Icons.star_outline_rounded, 'Reviews', onTap: () => _open(context, const ReviewsScreen())),
                _tile(context, Icons.description_outlined, 'Terms & Policies', onTap: () => _open(context, const TermsScreen())),
                _tile(context, Icons.headset_mic_outlined, 'Help & Support', onTap: () => _open(context, const SupportScreen())),
                const SizedBox(height: 24),
                const Text('GENERAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FT.inkSoft, letterSpacing: 1)),
                const SizedBox(height: 10),
                _tile(context, Icons.logout_rounded, 'Logout', color: FT.danger, onTap: () => _logout(context)),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '© 2026 FEEDTAN STORE',
                    style: const TextStyle(fontSize: 10.5, color: FT.inkSoft),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Logout?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Logout',
    );
    if (!ok || !context.mounted) return;
    shellTab.value = 0;
    await context.read<RiderSession>().signOut();
    if (context.mounted) showFTSnack(context, 'Logged out successfully');
  }

  Widget _header(Rider rider) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [FT.green800, FT.green600]),
            shape: BoxShape.circle,
          ),
          child: Text(
            rider.initials,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(rider.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: FT.ink)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 16, color: FT.green600),
                ],
              ),
              const SizedBox(height: 3),
              Text(rider.phone, style: const TextStyle(fontSize: 12.5, color: FT.inkSoft)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rider.isActive ? FT.green50 : FT.goldLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  rider.isActive ? 'Active Rider' : 'Inactive',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: rider.isActive ? FT.green700 : FT.goldDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vehicleCard(Rider rider) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                const Text('MY VEHICLE', style: TextStyle(fontSize: 10.5, color: FT.inkSoft, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  rider.vehicleType ?? 'Not set',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: FT.ink),
                ),
                Text(
                  rider.vehiclePlate ?? '',
                  style: const TextStyle(fontSize: 12, color: FT.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            '${rider.rating} ★',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: FT.goldDark),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color color = FT.ink,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FTCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color == FT.danger ? FT.danger : FT.green700),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: FT.inkSoft),
          ],
        ),
      ),
    );
  }
}

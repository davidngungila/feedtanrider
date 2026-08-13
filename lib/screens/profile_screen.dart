import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/app_errors.dart';
import '../state/session.dart';
import '../state/tabs.dart';
import '../theme.dart';
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
        _ProfileAvatar(rider: rider),
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

class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({required this.rider});

  final Rider rider;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final session = context.read<RiderSession>();
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (await picked.length() > 4 * 1024 * 1024) {
        if (mounted) showFTError(context, StateError('Image is larger than 4 MB.'));
        return;
      }
      setState(() => _busy = true);
      await session.uploadProfileImage(File(picked.path));
      if (mounted) showFTSnack(context, 'Profile image updated', background: FT.green700);
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final session = context.read<RiderSession>();
    final ok = await confirmDialog(
      context,
      title: 'Remove photo?',
      message: 'Your profile image will be removed.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await session.removeProfileImage();
      if (mounted) showFTSnack(context, 'Profile image removed');
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showOptions() async {
    if (_busy) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => FTGlassDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.account_circle_rounded, color: FT.green700, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Profile photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how to update your photo',
              style: TextStyle(fontSize: 12.5, color: FT.inkSoft),
            ),
            const SizedBox(height: 6),
            _option(ctx, Icons.photo_camera_rounded, 'Take a photo', 'camera'),
            _option(ctx, Icons.photo_library_rounded, 'Choose from gallery', 'gallery'),
            if (widget.rider.hasProfileImage)
              _option(ctx, Icons.delete_outline_rounded, 'Remove photo', 'remove',
                  color: FT.danger),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'camera':
        await _pick(ImageSource.camera);
        break;
      case 'gallery':
        await _pick(ImageSource.gallery);
        break;
      case 'remove':
        await _remove();
        break;
    }
  }

  Widget _option(BuildContext context, IconData icon, String label, String value,
      {Color color = FT.ink}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color == FT.danger ? FT.danger : FT.green700),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    return GestureDetector(
      onTap: _showOptions,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: rider.hasProfileImage
                ? Image.network(
                    rider.profileImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(rider),                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : _fallback(rider),
                  )
                : _fallback(rider),
          ),
          if (_busy)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: FT.green600),
              ),
            )
          else
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 25,
                height: 25,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: FT.green700,
                  shape: BoxShape.circle,
                  border: Border.all(color: FT.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(Rider rider) {
    return Container(
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
    );
  }
}

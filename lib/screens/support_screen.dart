import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getRiderSupport();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.getRiderSupport());
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}'), mode: LaunchMode.externalApplication);
  }

  Future<void> _mail(String? email) async {
    if (email == null || email.isEmpty) return;
    await launchUrl(Uri.parse('mailto:$email'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(title: const Text('Help & Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      body: GlassBackground(
        child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: FT.green700));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44, color: FT.inkSoft),
                  const SizedBox(height: 12),
                  Text(ApiService.errorMessage(snapshot.error), style: const TextStyle(fontSize: 13, color: FT.inkSoft)),
                  const SizedBox(height: 16),
                  FTButton(label: 'Retry', onTap: _reload, icon: Icons.refresh_rounded),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          final email = data['support_email'];
          final phone = data['support_phone'];
          final address = data['support_address'];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const FTCard(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.headset_mic_rounded, size: 44, color: FT.green700),
                    SizedBox(height: 10),
                    Text('We are here to help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: FT.ink)),
                    SizedBox(height: 4),
                    Text('Contact the Feedtan Store support team', style: TextStyle(fontSize: 12, color: FT.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (phone != null && phone.toString().isNotEmpty) ...[
                _contactTile(Icons.phone_rounded, 'Call support', phone.toString(), () => _call(phone.toString())),
                const SizedBox(height: 10),
              ],
              if (email != null && email.toString().isNotEmpty) ...[
                _contactTile(Icons.email_rounded, 'Email support', email.toString(), () => _mail(email.toString())),
                const SizedBox(height: 10),
              ],
              if (address != null && address.toString().isNotEmpty)
                _contactTile(Icons.location_on_rounded, 'Address', address.toString(), null),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _contactTile(IconData icon, String label, String value, VoidCallback? onTap) {
    return FTCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: FT.green50, shape: BoxShape.circle),
            child: Icon(icon, color: FT.green700, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: FT.inkSoft)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: FT.ink)),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: FT.inkSoft),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getTermsPolicies();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.getTermsPolicies());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(title: const Text('Terms & Policies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
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
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _section('Rider Terms', data['rider_terms']),
              _section('Rider Privacy Policy', data['rider_privacy_policy']),
              _section('Terms of Service', data['terms_of_service']),
              _section('Privacy Policy', data['privacy_policy']),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _section(String title, dynamic content) {
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FTCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: FT.ink)),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 12.5, color: FT.inkSoft, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

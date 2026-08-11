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

  static const _sections = [
    _Section(
      icon: Icons.verified_user_rounded,
      title: '1. Rider Eligibility',
      body:
          'By registering you confirm you are at least 18 years old, hold a valid '
          'driving licence, and own or have lawful access to the vehicle you use. '
          'You agree to keep your personal, licence and vehicle details up to date at '
          'all times.',
    ),
    _Section(
      icon: Icons.two_wheeler_rounded,
      title: '2. Delivery Responsibilities',
      body:
          'You are responsible for collecting orders from the shop on time, handling '
          'packages with care, following the provided route, and delivering to the '
          'customer at the exact address shown in the app. Delivering to a different '
          'address or handing over an order to anyone other than the customer is not '
          'permitted.',
    ),
    _Section(
      icon: Icons.schedule_rounded,
      title: '3. Availability & Acceptance',
      body:
          'When you go online you commit to accepting reasonable dispatch requests. '
          'Repeatedly declining or failing to respond to offers may reduce the '
          'dispatch offers you receive. Once you accept an order you must complete it; '
          'you cannot reassign or cancel it without the shop\u2019s approval.',
    ),
    _Section(
      icon: Icons.local_shipping_rounded,
      title: '4. Order & Packaging Checks',
      body:
          'Before leaving the shop, verify the order number, item count and condition '
          'of the package. Report any discrepancy or damaged item to the shop before '
          'departure. Once you leave the shop you are accountable for the package in '
          'your possession.',
    ),
    _Section(
      icon: Icons.payments_rounded,
      title: '5. Payments & Earnings',
      body:
          'Delivery fees are shown in the app before you accept. Cash-on-delivery '
          'orders require you to collect the exact amount from the customer and remit '
          'it to the shop or its authorised representative. Earnings may be adjusted '
          'for disputed or unremitted cash orders.',
    ),
    _Section(
      icon: Icons.phone_rounded,
      title: '6. Customer Contact',
      body:
          'Contact the customer only through the app-provided number and only for '
          'delivery-related reasons. Never share the customer\u2019s details with third '
          'parties. Behaviour that is abusive, discriminatory or unprofessional is a '
          'breach of these terms.',
    ),
    _Section(
      icon: Icons.gps_fixed_rounded,
      title: '7. Location & Tracking',
      body:
          'The app shares your live location with the shop and customer while you are '
          'on a delivery. Keep location services enabled and the app in the foreground '
          'so the delivery can be tracked. You consent to this tracking by using the '
          'app.',
    ),
    _Section(
      icon: Icons.directions_bike_rounded,
      title: '8. Road Safety',
      body:
          'Always obey traffic laws, wear appropriate safety gear, and never use your '
          'phone while riding. FeedTan Store is not liable for fines, accidents or '
          'losses caused by your actions on the road.',
    ),
    _Section(
      icon: Icons.account_balance_wallet_rounded,
      title: '9. Fees & Suspensions',
      body:
          'Orders not delivered due to rider negligence, or cash not remitted, may be '
          'deducted from your earnings. Repeated violations may lead to suspension or '
          'permanent deactivation of your rider account.',
    ),
    _Section(
      icon: Icons.verified_rounded,
      title: '10. Account & Data',
      body:
          'Your account is personal and must not be shared. You agree to FeedTan '
          'Store storing the information you provide to run the service and meet legal '
          'obligations. You may request deletion of your data at any time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(
        title: const Text('Terms & Conditions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: GlassBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
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
              );
            }
            final apiSections = _apiSections(snapshot.data);
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
                  const _Intro(),
                  const SizedBox(height: 18),
                  if (apiSections.isNotEmpty)
                    ...apiSections
                  else
                    ...[
                      for (final s in _sections) _sectionCard(s),
                    ],
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Last updated: 12 August 2026',
                      style: TextStyle(fontSize: 11, color: FT.inkSoft),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _apiSections(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final entries = <String, dynamic>{
      'Terms of Service': data['terms_of_service'],
      'Privacy Policy': data['privacy_policy'],
      'Rider Terms': data['rider_terms'],
      'Rider Privacy Policy': data['rider_privacy_policy'],
    };
    final widgets = <Widget>[];
    for (final e in entries.entries) {
      final text = e.value?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      widgets.add(_sectionCard(_Section(
        icon: Icons.description_rounded,
        title: e.key,
        body: text,
      )));
    }
    return widgets;
  }

  Widget _sectionCard(_Section s) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [FT.green800, FT.green600]),
              shape: BoxShape.circle,
            ),
            child: Icon(s.icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: FT.ink)),
                const SizedBox(height: 6),
                Text(s.body, style: const TextStyle(fontSize: 12.5, color: FT.inkSoft, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: FT.goldLight, shape: BoxShape.circle),
            child: const Icon(Icons.menu_book_rounded, color: FT.goldDark, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Please read carefully', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: FT.ink)),
                SizedBox(height: 4),
                Text(
                  'These terms govern your use of the FeedTan Store rider app and the '
                  'delivery services you provide. By using the app you agree to them.',
                  style: TextStyle(fontSize: 12.5, color: FT.inkSoft, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

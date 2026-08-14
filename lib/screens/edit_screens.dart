import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/app_errors.dart';
import '../state/session.dart';
import '../theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rider = context.read<RiderSession>().rider;
    if (rider != null) {
      _nameCtrl.text = rider.name;
      _phoneCtrl.text = rider.phone;
      _dobCtrl.text = rider.dateOfBirth ?? '';
      _genderCtrl.text = rider.gender ?? '';
      _addressCtrl.text = rider.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final parsed = DateTime.tryParse(_dobCtrl.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: FT.green700),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    final session = context.read<RiderSession>();
    setState(() => _loading = true);
    try {
      await ApiService.instance.updatePersonalInfo({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'date_of_birth': _dobCtrl.text.trim(),
        'gender': _genderCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });
      await session.refreshProfile();
      if (!mounted) return;
      showFTSnack(context, 'Personal info updated', background: FT.green700);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScreen(
      title: 'Personal Information',
      subtitle: 'Update your name, phone and address',
      children: [
        TextField(controller: _nameCtrl, decoration: ftInputDecoration(label: 'Full name', icon: Icons.person_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: ftInputDecoration(label: 'Phone', icon: Icons.phone_rounded)),
        const SizedBox(height: 14),
        TextField(
          controller: _dobCtrl,
          readOnly: true,
          onTap: _pickDob,
          decoration: ftInputDecoration(
            label: 'Date of birth (YYYY-MM-DD)',
            icon: Icons.cake_rounded,
            suffix: const Icon(Icons.calendar_month_rounded, color: FT.green600, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        TextField(controller: _genderCtrl, decoration: ftInputDecoration(label: 'Gender', icon: Icons.wc_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _addressCtrl, maxLines: 2, decoration: ftInputDecoration(label: 'Address', icon: Icons.home_rounded)),
        const SizedBox(height: 22),
        FTButton(label: 'Save Changes', onTap: _save, loading: _loading, icon: Icons.save_rounded),
      ],
    );
  }
}

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _typeCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rider = context.read<RiderSession>().rider;
    if (rider != null) {
      _typeCtrl.text = rider.vehicleType ?? '';
      _plateCtrl.text = rider.vehiclePlate ?? '';
      _modelCtrl.text = rider.vehicleModel ?? '';
      _colorCtrl.text = rider.vehicleColor ?? '';
      _yearCtrl.text = rider.vehicleYear ?? '';
    }
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _plateCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final current = int.tryParse(_yearCtrl.text) ?? now.year;
    final years = [for (var y = now.year; y >= 1980; y--) y];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => FTGlassDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: FT.green700, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Select year', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.7,
                children: [
                  for (final y in years)
                    InkWell(
                      key: ValueKey(y),
                      onTap: () => Navigator.pop(ctx, y),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: y == current ? FT.green100 : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: y == current ? FT.green600 : FT.line),
                        ),
                        child: Text(
                          '$y',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: y == current ? FT.green800 : FT.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      _yearCtrl.text = '$selected';
    }
  }

  Future<void> _save() async {
    final session = context.read<RiderSession>();
    setState(() => _loading = true);
    try {
      await ApiService.instance.updateVehicle({
        'vehicle_type': _typeCtrl.text.trim(),
        'vehicle_plate': _plateCtrl.text.trim(),
        'vehicle_model': _modelCtrl.text.trim(),
        'vehicle_color': _colorCtrl.text.trim(),
        'vehicle_year': _yearCtrl.text.trim(),
      });
      await session.refreshProfile();
      if (!mounted) return;
      showFTSnack(context, 'Vehicle details updated', background: FT.green700);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScreen(
      title: 'Vehicle Details',
      subtitle: 'Keep your vehicle info up to date',
      children: [
        TextField(controller: _typeCtrl, decoration: ftInputDecoration(label: 'Vehicle type', hint: 'Motorcycle', icon: Icons.two_wheeler_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _plateCtrl, textCapitalization: TextCapitalization.characters, decoration: ftInputDecoration(label: 'Plate number', icon: Icons.pin_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _modelCtrl, decoration: ftInputDecoration(label: 'Vehicle model', icon: Icons.model_training_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _colorCtrl, decoration: ftInputDecoration(label: 'Vehicle color', icon: Icons.palette_rounded)),
        const SizedBox(height: 14),
        TextField(
          controller: _yearCtrl,
          readOnly: true,
          onTap: _pickYear,
          decoration: ftInputDecoration(
            label: 'Vehicle year',
            icon: Icons.calendar_today_rounded,
            suffix: const Icon(Icons.calendar_month_rounded, color: FT.green600, size: 20),
          ),
        ),
        const SizedBox(height: 22),
        FTButton(label: 'Save Changes', onTap: _save, loading: _loading, icon: Icons.save_rounded),
      ],
    );
  }
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _nidCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();
  final _dlExpiryCtrl = TextEditingController();
  final _insCtrl = TextEditingController();
  final _insExpiryCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rider = context.read<RiderSession>().rider;
    if (rider != null) {
      _nidCtrl.text = rider.nidNumber ?? '';
      _dlCtrl.text = rider.drivingLicenseNumber ?? '';
      _dlExpiryCtrl.text = rider.licenseExpiryDate ?? '';
      _insCtrl.text = rider.insuranceNumber ?? '';
      _insExpiryCtrl.text = rider.insuranceExpiryDate ?? '';
    }
  }

  @override
  void dispose() {
    _nidCtrl.dispose();
    _dlCtrl.dispose();
    _dlExpiryCtrl.dispose();
    _insCtrl.dispose();
    _insExpiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl, {required String label}) async {
    final parsed = DateTime.tryParse(ctrl.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: label,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: FT.green700),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    final session = context.read<RiderSession>();
    setState(() => _loading = true);
    try {
      await ApiService.instance.updateDocuments({
        'nid_number': _nidCtrl.text.trim(),
        'driving_license_number': _dlCtrl.text.trim(),
        'license_expiry_date': _dlExpiryCtrl.text.trim(),
        'insurance_number': _insCtrl.text.trim(),
        'insurance_expiry_date': _insExpiryCtrl.text.trim(),
      });
      await session.refreshProfile();
      if (!mounted) return;
      showFTSnack(context, 'Documents updated', background: FT.green700);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScreen(
      title: 'Documents & License',
      subtitle: 'NID, driving license and insurance details',
      children: [
        TextField(controller: _nidCtrl, keyboardType: TextInputType.number, decoration: ftInputDecoration(label: 'NID number', icon: Icons.credit_card_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _dlCtrl, decoration: ftInputDecoration(label: 'Driving license number', icon: Icons.badge_outlined)),
        const SizedBox(height: 14),
        TextField(
          controller: _dlExpiryCtrl,
          readOnly: true,
          onTap: () => _pickDate(_dlExpiryCtrl, label: 'License expiry'),
          decoration: ftInputDecoration(
            label: 'License expiry (YYYY-MM-DD)',
            icon: Icons.event_rounded,
            suffix: const Icon(Icons.calendar_month_rounded, color: FT.green600, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        TextField(controller: _insCtrl, decoration: ftInputDecoration(label: 'Insurance number', icon: Icons.verified_user_rounded)),
        const SizedBox(height: 14),
        TextField(
          controller: _insExpiryCtrl,
          readOnly: true,
          onTap: () => _pickDate(_insExpiryCtrl, label: 'Insurance expiry'),
          decoration: ftInputDecoration(
            label: 'Insurance expiry (YYYY-MM-DD)',
            icon: Icons.event_rounded,
            suffix: const Icon(Icons.calendar_month_rounded, color: FT.green600, size: 20),
          ),
        ),
        const SizedBox(height: 22),
        FTButton(label: 'Save Changes', onTap: _save, loading: _loading, icon: Icons.save_rounded),
      ],
    );
  }
}

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  final _bankNameCtrl = TextEditingController();
  final _acctNumCtrl = TextEditingController();
  final _acctNameCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _mmNumCtrl = TextEditingController();
  final _mmProviderCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rider = context.read<RiderSession>().rider;
    if (rider != null) {
      _bankNameCtrl.text = rider.bankName ?? '';
      _acctNumCtrl.text = rider.bankAccountNumber ?? '';
      _acctNameCtrl.text = rider.bankAccountName ?? '';
      _branchCtrl.text = rider.bankBranch ?? '';
      _mmNumCtrl.text = rider.mobileMoneyNumber ?? '';
      _mmProviderCtrl.text = rider.mobileMoneyProvider ?? '';
    }
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _acctNumCtrl.dispose();
    _acctNameCtrl.dispose();
    _branchCtrl.dispose();
    _mmNumCtrl.dispose();
    _mmProviderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<RiderSession>();
    setState(() => _loading = true);
    try {
      await ApiService.instance.updateBankDetails({
        'bank_name': _bankNameCtrl.text.trim(),
        'bank_account_number': _acctNumCtrl.text.trim(),
        'bank_account_name': _acctNameCtrl.text.trim(),
        'bank_branch': _branchCtrl.text.trim(),
        'mobile_money_number': _mmNumCtrl.text.trim(),
        'mobile_money_provider': _mmProviderCtrl.text.trim(),
      });
      await session.refreshProfile();
      if (!mounted) return;
      showFTSnack(context, 'Bank details updated', background: FT.green700);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScreen(
      title: 'Bank & Mobile Money',
      subtitle: 'Your earnings payout details',
      children: [
        const Text('BANK ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FT.inkSoft, letterSpacing: 1)),
        const SizedBox(height: 10),
        TextField(controller: _bankNameCtrl, decoration: ftInputDecoration(label: 'Bank name', icon: Icons.account_balance_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _acctNumCtrl, keyboardType: TextInputType.number, decoration: ftInputDecoration(label: 'Account number', icon: Icons.numbers_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _acctNameCtrl, decoration: ftInputDecoration(label: 'Account name', icon: Icons.person_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _branchCtrl, decoration: ftInputDecoration(label: 'Bank branch', icon: Icons.location_city_rounded)),
        const SizedBox(height: 20),
        const Text('MOBILE MONEY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FT.inkSoft, letterSpacing: 1)),
        const SizedBox(height: 10),
        TextField(controller: _mmNumCtrl, keyboardType: TextInputType.phone, decoration: ftInputDecoration(label: 'Mobile money number', icon: Icons.smartphone_rounded)),
        const SizedBox(height: 14),
        TextField(controller: _mmProviderCtrl, decoration: ftInputDecoration(label: 'Provider (e.g. M-Pesa)', icon: Icons.swap_horiz_rounded)),
        const SizedBox(height: 22),
        FTButton(label: 'Save Changes', onTap: _save, loading: _loading, icon: Icons.save_rounded),
      ],
    );
  }
}

class _FormScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _FormScreen({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      body: GlassBackground(
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: FT.inkSoft)),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 30),
          ],
        ),
        ),
      ),
    );
  }
}

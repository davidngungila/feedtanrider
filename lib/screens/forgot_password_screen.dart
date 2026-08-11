import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_errors.dart';
import '../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showFTErrorPopup(
        context,
        title: 'Invalid Email',
        message: 'Please enter a valid email address',
        code: 'AUTH_001',
        icon: Icons.email_rounded,
        color: FT.danger,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.instance.forgotPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) showFTError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(
        title: const Text('Forgot Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: GlassBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: _sent ? _successView() : _formView(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: FT.green50,
            shape: BoxShape.circle,
            border: Border.all(color: FT.green700.withValues(alpha: 0.3), width: 2),
          ),
          child: const Icon(Icons.lock_reset_rounded, size: 40, color: FT.green700),
        ),
        const SizedBox(height: 24),
        const Text(
          'Forgot your password?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: FT.ink),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your email address and we\'ll send you a link to reset your password.',
          style: TextStyle(fontSize: 13, color: FT.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: ftInputDecoration(
            label: 'Email',
            hint: 'rider@example.com',
            icon: Icons.alternate_email_rounded,
            glass: true,
          ),
        ),
        const SizedBox(height: 24),
        FTButton(
          label: 'Send Reset Link',
          onTap: _submit,
          loading: _loading,
          icon: Icons.send_rounded,
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Back to Login',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FT.green700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _successView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: FT.green50,
            shape: BoxShape.circle,
            border: Border.all(color: FT.green700.withValues(alpha: 0.3), width: 2),
          ),
          child: const Icon(Icons.check_circle_rounded, size: 50, color: FT.green700),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check your email',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: FT.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a password reset link to ${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: FT.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'Didn\'t receive the email? Check your spam folder or try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: FT.inkSoft),
        ),
        const SizedBox(height: 32),
        FTButton(
          label: 'Back to Login',
          onTap: () => Navigator.pop(context),
          icon: Icons.arrow_back_rounded,
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () {
              setState(() => _sent = false);
            },
            child: const Text(
              'Try another email',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FT.inkSoft),
            ),
          ),
        ),
      ],
    );
  }
}

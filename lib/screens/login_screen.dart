import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_errors.dart';
import '../state/session.dart';
import '../theme.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
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
    if (password.isEmpty) {
      showFTErrorPopup(
        context,
        title: 'Password Required',
        message: 'Please enter your password',
        code: 'AUTH_001',
        icon: Icons.lock_rounded,
        color: FT.danger,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<RiderSession>().signIn(email, password);
      if (!mounted) return;
      showFTSnack(context, 'Welcome back!', background: FT.green700);
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
      body: GlassBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      const _BrandLockup(),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: glassCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FT.ink),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sign in to start earning on your schedule',
                              style: TextStyle(fontSize: 12.5, color: FT.inkSoft),
                            ),
                            const SizedBox(height: 24),
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
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              onSubmitted: (_) => _submit(),
                              decoration: ftInputDecoration(
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_rounded,
                                glass: true,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: FT.inkSoft,
                                    size: 19,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: FT.green700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FTButton(
                              label: 'Sign In',
                              onTap: _submit,
                              loading: _loading,
                              icon: Icons.two_wheeler_rounded,
                            ),
                            const SizedBox(height: 18),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.security_rounded, size: 14, color: FT.inkSoft),
                                SizedBox(width: 6),
                                Text(
                                  'Your credentials are stored securely',
                                  style: TextStyle(fontSize: 11.5, color: FT.inkSoft),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Need help?', style: TextStyle(fontSize: 12, color: FT.inkSoft)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => showFTSnack(context, 'Email support@feedtanstore.com'),
                            child: const Text(
                              'Contact support',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: FT.green700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
            boxShadow: [
              BoxShadow(
                color: FT.green700.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Image(
            image: AssetImage('assets/images/logo.png'),
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'FEEDTAN',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: FT.green700,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2, offset: const Offset(0, 1))],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'RIDER',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: FT.ink,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2, offset: const Offset(0, 1))],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Delivery Partner',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FT.inkSoft, letterSpacing: 3),
        ),
      ],
    );
  }
}

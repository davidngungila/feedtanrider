import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'services/push_service.dart';
import 'state/session.dart';
import 'state/session_expired.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (AppConfig.firebaseEnabled) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.instance.init();
  }
  runApp(const RiderApp());
}

class RiderApp extends StatefulWidget {
  const RiderApp({super.key});

  @override
  State<RiderApp> createState() => _RiderAppState();
}

class _RiderAppState extends State<RiderApp> {
  final RiderSession _session = RiderSession();

  @override
  void initState() {
    super.initState();
    ApiSessionExpiredBinder.bind(_session);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: MaterialApp(
        title: 'FEEDTAN RIDER',
        debugShowCheckedModeBanner: false,
        navigatorKey: ApiSessionExpiredBinder.navigatorKey,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: FT.bg,
          textTheme: GoogleFonts.manropeTextTheme(),
          colorScheme: ColorScheme.fromSeed(
            seedColor: FT.green700,
            primary: FT.green700,
            secondary: FT.gold,
            surface: FT.white,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white.withValues(alpha: 0.55),
            foregroundColor: FT.ink,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white.withValues(alpha: 0.55),
            indicatorColor: FT.green50,
            surfaceTintColor: Colors.transparent,
            height: 68,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: selected ? 11 : 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                color: selected ? FT.green700 : FT.inkSoft,
              );
            }),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: FT.ink,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: FT.green50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  @override
  void initState() {
    super.initState();
    context.read<RiderSession>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<RiderSession>();
    if (!session.initialized) return const SplashScreen();
    return session.loggedIn ? const MainShell() : const LoginScreen();
  }
}

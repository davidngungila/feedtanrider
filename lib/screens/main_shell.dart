import 'dart:ui';

import 'package:flutter/material.dart';

import '../state/tabs.dart';
import '../theme.dart';
import 'available_screen.dart';
import 'dashboard_screen.dart';
import 'my_orders_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    shellTab.value = 0;
    shellTab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      extendBody: true,
      body: GlassBackground(
        child: IndexedStack(
          index: shellTab.value,
          children: const [
            DashboardScreen(),
            AvailableScreen(),
            MyOrdersScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: NavigationBar(
            selectedIndex: shellTab.value,
            onDestinationSelected: (i) => shellTab.value = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined, color: FT.inkSoft),
            selectedIcon: Icon(Icons.space_dashboard_rounded, color: FT.green700),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded, color: FT.inkSoft),
            selectedIcon: Icon(Icons.notifications_rounded, color: FT.green700),
            label: 'Available',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: FT.inkSoft),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: FT.green700),
            label: 'My Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: FT.inkSoft),
            selectedIcon: Icon(Icons.person_rounded, color: FT.green700),
            label: 'Profile',
          ),
        ],
          ),
        ),
      ),
    );
  }
}

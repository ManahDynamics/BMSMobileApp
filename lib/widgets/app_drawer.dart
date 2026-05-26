// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/dashboard.dart';
import 'package:bmsmobileapp/screens/cells_screen.dart';
import 'package:bmsmobileapp/screens/alerts_screen.dart';
import 'package:bmsmobileapp/screens/settings_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

class AppDrawer extends StatelessWidget {
  final String activeRoute;
  final BMSBluetoothService service;

  const AppDrawer({
    super.key,
    required this.activeRoute,
    required this.service,
  });

  String tr(String key) {
    return TranslationService.t(key);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0B6645),
      width: MediaQuery.of(context).size.width * 0.78,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: -130,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: 200,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Text(
                          'VC',
                          style: TextStyle(
                            color: Color(0xFF1B6B3A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Venkat Cherka',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'ID: ABC28348624',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // ── All nav items now pass service ──────────────────────
                _buildNavItem(
                  context,
                  icon: Icons.home_rounded,
                  label: tr('drawer.dashboard'),
                  route: '/dashboard',
                  page: DashboardScreen(service: service),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.battery_full_rounded,
                  label: tr('drawer.cells'),
                  route: '/cells',
                  page: CellsScreen(service: service),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.notifications_rounded,
                  label: tr('drawer.alerts'),
                  route: '/alerts',
                  page: AlertsScreen(service: service),
                ),
                _buildNavItem(
                  context,
                  icon: Icons.settings_rounded,
                  label: tr('drawer.settings'),
                  route: '/settings',
                  page: SettingsScreen(service: service),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Widget page,
  }) {
    final bool isActive = activeRoute == route;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (!isActive) {
          Navigator.pushReplacement(context, SlideRoute(page: page));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0A5338) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

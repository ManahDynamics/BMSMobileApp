import 'package:flutter/material.dart';
import 'package:bmsmobileapp/core/api/maintenance_service.dart';
// import '../services/auth_service.dart';
import '../../auth/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Only check maintenance at splash
    final status = await MaintenanceService.check();

    if (!mounted) return;

    if (status == MaintenanceStatus.maintenance) {
      Navigator.pushReplacementNamed(context, '/maintenance');
      return;
    }

    // Server ok → check auth
    final token = await AuthService.getAccessToken();
    // final isExpired = token != null
    //     ? await AuthService.isTokenExpired(token)
    //     : true;

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(),
    );
  }
}
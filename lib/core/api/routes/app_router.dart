import 'package:flutter/material.dart';
import '../../../modules/auth/screens/splash_screen.dart';
import '../../../modules/auth/screens/login_screen.dart';
import '../../../modules/registration/screens/registration_screen.dart';
import '../../../modules/connect/screens/connect_screen.dart';
// import '../../../modules/scanner/screens/bluetooth_device_scan_screen.dart';
import '../../../screens/forgotpassword_screen.dart';
import '../../../screens/dashboard.dart';
import '../../../screens/alerts_screen.dart';
import '../../../screens/bluetooth_device_scan_screen.dart';
import '../../../screens/cells_screen.dart';
// import '../../../screens/connect_screen.dart';
import '../../../screens/editprofile_screen.dart';
import '../../../screens/settings_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';

class AppRoutes {
  static const String splash        = '/splash';
  static const String login         = '/login';
  static const String register      = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard     = '/dashboard';
  static const String alerts        = '/alerts';
  static const String bluetoothScan = '/bluetooth-scan';
  static const String cells         = '/cells';
  static const String connect       = '/connect';
  static const String editProfile   = '/edit-profile';
  static const String settings      = '/settings';
  static const String serverDown    = '/server-down';
}

class AppRouter {
  static final BMSBluetoothService bmsService = BMSBluetoothService();

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case AppRoutes.dashboard:
        return MaterialPageRoute(
          builder: (_) => DashboardScreen(service: bmsService),
        );

      case AppRoutes.alerts:
        return MaterialPageRoute(
          builder: (_) => AlertsScreen(service: bmsService),
        );

      case AppRoutes.bluetoothScan:
        return MaterialPageRoute(
          builder: (_) => BluetoothDeviceScanPage(service: bmsService),
        );

      case AppRoutes.cells:
        return MaterialPageRoute(
          builder: (_) => CellsScreen(service: bmsService),
        );

      case AppRoutes.connect:
        return MaterialPageRoute(builder: (_) => const ConnectScreen());

      case AppRoutes.editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) =>  SettingsScreen(service: bmsService));

      case AppRoutes.serverDown:
        return MaterialPageRoute(builder: (_) => const ServerDownScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }
}

class ServerDownScreen extends StatelessWidget {
  const ServerDownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Server Unavailable',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your connection and try again',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.dashboard);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
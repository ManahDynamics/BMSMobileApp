import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard.dart';
import 'screens/editprofile_screen.dart';
import 'screens/forgotpassword_screen.dart';

import 'services/bluetooth_service.dart';

/// Global bluetooth service — single instance used across the entire app
final BMSBluetoothService bmsService = BMSBluetoothService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart BMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7D4F),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash':          (context) => const SplashScreen(),
        '/login':           (context) => const LoginScreen(),
        '/register':        (context) => const RegisterScreen(),
        '/connect':         (context) => const ConnectScreen(),
        '/dashboard':       (context) => DashboardScreen(service: bmsService),
        '/edit_profile':    (context) => const EditProfileScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}
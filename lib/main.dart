import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard.dart';
import 'screens/editprofile_screen.dart';
import 'screens/forgotpassword_screen.dart';

import 'services/bluetooth_service.dart';
import 'services/translation_service.dart';

/// Global bluetooth service - single instance used across the entire app
final BMSBluetoothService bmsService = BMSBluetoothService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// Load default language from Firestore and subscribe to realtime updates.
  await TranslationService.loadTranslations('en');

  /// Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  /// Global language switch method
  static Future<void> changeLanguage(
    BuildContext context,
    String lang,
  ) async {
    final state = context.findAncestorStateOfType<_MyAppState>();
    if (state != null) {
      await state.changeLanguage(lang);
    }
  }
}

class _MyAppState extends State<MyApp> {
  String currentLanguage = 'en';

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationChanged);
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationChanged);
    super.dispose();
  }

  void _onTranslationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Change language dynamically
  Future<void> changeLanguage(String lang) async {
    await TranslationService.setLanguage(lang);
    if (mounted) {
      setState(() {
        currentLanguage = lang;
      });
    }
  }

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
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B6B3A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      key: ValueKey(currentLanguage),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/connect': (context) => const ConnectScreen(),
        '/dashboard': (context) => DashboardScreen(
              service: bmsService,
            ),
        '/edit_profile': (context) => const EditProfileScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}

// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/api/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

import 'services/bluetooth_service.dart';
import 'services/translation_service.dart';
import 'services/device_token_service.dart'; // ← NEW

/// Global bluetooth service - single instance used across the entire app
final BMSBluetoothService bmsService = BMSBluetoothService();

/// Background FCM message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  /// Fetch and log real-time device token on app start (optional: for debugging)
  final deviceInfo = await DeviceTokenService.getDeviceInfo();
  debugPrint('[Main] Device Token   : ${deviceInfo['deviceToken']}');
  debugPrint('[Main] Device ID      : ${deviceInfo['deviceId']}');
  debugPrint('[Main] Device Platform: ${deviceInfo['devicePlatform']}');

  /// Listen for foreground FCM messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
  });

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

      // === New Theme Integration ===
      theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,        // Enable when you add dark mode
      // themeMode: ThemeMode.system,          // Or .light / .dark

      key: ValueKey(currentLanguage), // Refresh UI when language changes
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.generateRoute,

      // Optional: You can still override specific theme properties if needed
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling, // Optional: Prevent system font scaling
          ),
          child: child!,
        );
      },
    );
  }
}
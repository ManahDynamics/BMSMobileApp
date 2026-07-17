// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_navigator.dart';
import 'widgets/common_dialog.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/api/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

import 'services/bluetooth_service.dart';
import 'services/translation_service.dart';
import 'services/device_token_service.dart';
import 'services/offline_sync_service.dart'; // ← NEW

/// Global bluetooth service - single instance used across the entire app

/// Global offline sync service - single instance used across the entire app
final OfflineSyncService offlineSyncService = OfflineSyncService(); // ← NEW

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

  /// Start listening for connectivity changes so any SQLite-queued data
  /// (from LocalAuthDB.enqueueForSync / OfflineSyncService.saveAndQueue,
  /// or automatically via saveDashboard/saveCellVoltage/saveAlerts/
  /// saveSettings/saveDeviceName) gets flushed to Firestore automatically,
  /// and also does one sync pass immediately on app start in case there's
  /// a backlog from while the app was offline.
  await offlineSyncService.startListening(); // ← NEW

  /// Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
AppRouter.bmsService.onBmsDisconnectedFatal = () {
    debugPrint("✅ Callback reached in main.dart");
  final context = appNavigatorKey.currentContext;
  debugPrint("Context = $context");

  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => CommonDialog(
      icon: Icons.bluetooth_disabled_rounded,
      iconColor: const Color(0xFFA63A3A),
      iconBackgroundColor: const Color(0xFFFDEEEE),
      title: "BMS disconnected",
      message: "The BMS has disconnected. The app is going to close.",
      buttonText: "OK",
      buttonColor: const Color(0xFF1D6A43),
      onPressed: () {
        Navigator.of(context).pop();
        SystemNavigator.pop();
      },
    ),
  );
};
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
    offlineSyncService.dispose(); // ← NEW
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
      navigatorKey: appNavigatorKey, 
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
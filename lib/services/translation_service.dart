import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class TranslationService {

  static final FirebaseRemoteConfig remoteConfig =
      FirebaseRemoteConfig.instance;

  static Map<String, dynamic> translations = {};

  /// Bundled fallbacks when Remote Config has no entry for a language.
  static const Map<String, Map<String, String>> _fallbackTranslations = {
    'en': {
      'login.app_title': 'BMS Mobile App',
      'login.app_subtitle': 'Smart Battery Management System',
      'connect.title': 'CONNECT',
      'connect.choose_device': 'Choose the Device option',
      'connect.local_monitoring': 'Local Monitoring',
      'connect.bluetooth_device': 'Bluetooth Device',
      'connect.remote_monitoring': 'Remote Monitoring',
      'connect.wifi_devices': 'Wifi or 4G/5G Devices',
      'connect.bluetooth_off': 'Bluetooth Off',
      'connect.enable_bluetooth': 'Please enable Bluetooth to continue.',
      'connect.ok': 'OK',
      'connect.remote_coming_soon': 'Remote monitoring coming soon!',
      'connect.bluetooth_not_supported': 'Bluetooth Not Supported',
      'connect.device_no_bluetooth':
          'This device does not support Bluetooth.',
    },
    'hi': {
      'login.app_title': 'BMS मोबाइल ऐप',
      'login.app_subtitle': 'स्मार्ट बैटरी प्रबंधन प्रणाली',
      'login.email_or_phone': 'ईमेल या फ़ोन',
      'login.password': 'पासवर्ड',
      'login.forgot_password': 'पासवर्ड भूल गए?',
      'login.login': 'लॉग इन',
      'login.no_account_prefix': 'खाता नहीं है? ',
      'login.register_here': 'यहाँ पंजीकरण करें',
      'register.title': 'पंजीकरण',
      'register.full_name': 'पूरा नाम',
      'register.email_or_phone': 'ईमेल या फ़ोन',
      'register.password': 'पासवर्ड',
      'register.confirm_password': 'पासवर्ड की पुष्टि करें',
      'register.register': 'पंजीकरण करें',
      'register.already_have_account': 'पहले से खाता है? ',
      'register.login': 'लॉग इन',
      'connect.title': 'कनेक्ट',
      'connect.choose_device': 'डिवाइस विकल्प चुनें',
      'connect.local_monitoring': 'स्थानीय निगरानी',
      'connect.bluetooth_device': 'ब्लूटूथ डिवाइस',
      'connect.remote_monitoring': 'दूरस्थ निगरानी',
      'connect.wifi_devices': 'वाईफाई या 4G/5G डिवाइस',
      'connect.bluetooth_off': 'ब्लूटूथ बंद',
      'connect.enable_bluetooth': 'जारी रखने के लिए ब्लूटूथ चालू करें।',
      'connect.ok': 'ठीक है',
      'connect.remote_coming_soon': 'दूरस्थ निगरानी जल्द आ रही है!',
      'connect.bluetooth_not_supported': 'ब्लूटूथ समर्थित नहीं',
      'connect.device_no_bluetooth':
          'यह डिवाइस ब्लूटूथ का समर्थन नहीं करता।',
    },
    'te': {
      'login.app_title': 'BMS మొబైల్ యాప్',
      'login.app_subtitle': 'స్మార్ట్ బ్యాటరీ మేనేజ్‌మెంట్ సిస్టమ్',
      'connect.title': 'కనెక్ట్',
      'connect.choose_device': 'పరికర ఎంపికను ఎంచుకోండి',
      'connect.local_monitoring': 'స్థానిక మానిటరింగ్',
      'connect.bluetooth_device': 'బ్లూటూత్ పరికరం',
      'connect.remote_monitoring': 'రిమోట్ మానిటరింగ్',
      'connect.wifi_devices': 'Wifi లేదా 4G/5G పరికరాలు',
      'connect.bluetooth_off': 'బ్లూటూత్ ఆఫ్',
      'connect.enable_bluetooth':
          'కొనసాగించడానికి బ్లూటూత్‌ను ప్రారంభించండి.',
      'connect.ok': 'సరే',
      'connect.remote_coming_soon': 'రిమోట్ మానిటరింగ్ త్వరలో వస్తుంది!',
      'connect.bluetooth_not_supported': 'బ్లూటూత్ మద్దతు లేదు',
      'connect.device_no_bluetooth':
          'ఈ పరికరం బ్లూటూత్‌కు మద్దతు ఇవ్వదు.',
    },
  };

  /// Load translations from Firebase
  static Future<void> loadTranslations(String lang) async {

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ),
    );

    final fallbackJson = json.encode(_fallbackTranslations[lang] ?? {});
    await remoteConfig.setDefaults({
      'translations_$lang': fallbackJson,
    });

    await remoteConfig.fetchAndActivate();

    final jsonString =
        remoteConfig.getString('translations_$lang');

    final remote = json.decode(jsonString) as Map<String, dynamic>;
    final fallback = _fallbackTranslations[lang] ?? {};

    translations = {...fallback, ...remote};

    print('Translations Loaded: $translations');
  }

  /// Get translation value
  static String t(String key) {
    return translations[key] ?? key;
  }
}
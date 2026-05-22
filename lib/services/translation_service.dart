import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class TranslationService {

  static final FirebaseRemoteConfig remoteConfig =
      FirebaseRemoteConfig.instance;

  static Map<String, dynamic> translations = {};

  /// Load translations from Firebase
  static Future<void> loadTranslations(String lang) async {

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ),
    );

    await remoteConfig.setDefaults({
      'translations_$lang': '{}',
    });

    await remoteConfig.fetchAndActivate();

    final jsonString =
        remoteConfig.getString('translations_$lang');

    translations = json.decode(jsonString);

    print('Translations Loaded: $translations');
  }

  /// Get translation value
  static String t(String key) {
    return translations[key] ?? key;
  }
}
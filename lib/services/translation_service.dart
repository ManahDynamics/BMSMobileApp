import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TranslationService extends ChangeNotifier {
  TranslationService._();

  static final TranslationService instance = TranslationService._();

  static final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  Map<String, dynamic> _translations = {};

  String _currentLanguage = 'en';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _translationSubscription;

  DocumentReference<Map<String, dynamic>> _languageDoc(
      String lang) {
    return firestore
        .collection('translations')
        .doc(lang);
  }

  Map<String, dynamic> get debugTranslations =>
      _translations;

  String get currentLanguage =>
      _currentLanguage;

  Future<void> _loadTranslations(
      String lang) async {
    if (_currentLanguage == lang &&
        _translationSubscription != null) {
      return;
    }

    _currentLanguage = lang;

    await _translationSubscription?.cancel();

    try {
      final docRef = _languageDoc(lang);

      // Initial Load
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        debugPrint(
          'Translation document does not exist: translations/$lang',
        );

        _translations = {};
        notifyListeners();
        return;
      }

      _translations =
          Map<String, dynamic>.from(
        snapshot.data() ?? {},
      );

      if (kDebugMode) {
        debugPrint(
          'Loaded translations for "$lang"',
        );

        debugPrint(
          'Keys count: ${_translations.length}',
        );

        debugPrint(
          'login.app_title => ${_translate('login.app_title')}',
        );
      }

      notifyListeners();

      // Realtime Listener
      _translationSubscription =
          docRef.snapshots().listen(
        (snapshot) {
          if (!snapshot.exists) {
            debugPrint(
              'Translation document removed: translations/$lang',
            );

            _translations = {};
            notifyListeners();
            return;
          }

          _translations =
              Map<String, dynamic>.from(
            snapshot.data() ?? {},
          );

          if (kDebugMode) {
            debugPrint(
              'Realtime update received for "$lang"',
            );

            debugPrint(
              'Keys count: ${_translations.length}',
            );

            debugPrint(
              'login.app_title => ${_translate('login.app_title')}',
            );
          }

          notifyListeners();
        },
        onError: (error) {
          debugPrint(
            'Translation listener error: $error',
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load translations for $lang',
      );

      debugPrint(error.toString());

      if (kDebugMode) {
        debugPrintStack(
          stackTrace: stackTrace,
        );
      }

      _translations = {};
      notifyListeners();
    }
  }

  Future<void> _setLanguage(
      String lang) async {
    await _loadTranslations(lang);
  }

  String _translate(String key) {
    final value =
        _getNestedValue(_translations, key);

    return value?.toString() ?? key;
  }

  dynamic _getNestedValue(
    Map<String, dynamic> map,
    String key,
  ) {
    // Supports flat keys:
    // login.app_title

    if (map.containsKey(key)) {
      return map[key];
    }

    // Supports nested maps:
    // login -> app_title

    final parts = key.split('.');

    dynamic current = map;

    for (final part in parts) {
      if (current is Map<String, dynamic> &&
          current.containsKey(part)) {
        current = current[part];
      } else if (current is Map &&
          current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  Future<void> disposeListener() async {
    await _translationSubscription?.cancel();
    _translationSubscription = null;
  }

  // Static wrappers

  static Future<void> loadTranslations(
      String lang) {
    return instance._loadTranslations(lang);
  }

  static Future<void> setLanguage(
      String lang) {
    return instance._setLanguage(lang);
  }

  static String t(String key) {
    return instance._translate(key);
  }

  static String get language =>
      instance._currentLanguage;
}
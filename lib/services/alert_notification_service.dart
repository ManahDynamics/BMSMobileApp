// lib/services/alert_notification_service.dart
//
// Shows a system notification for a BMS Alert Push (0x51) when the app
// has no active foreground context (backgrounded / between routes).
// The foreground case is already handled in main.dart via CommonDialog —
// this only covers the gap where that dialog can't be shown.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlertNotificationService {
  AlertNotificationService._internal();
  static final AlertNotificationService instance =
      AlertNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'bms_alerts_channel';
  static const _channelName = 'BMS Alerts';
  static const _channelDescription = 'Push alerts from the connected battery';

  /// Called if the user taps the system notification. Wire this in
  /// main.dart to navigate via appNavigatorKey to your alerts screen.
  void Function(int? alertId)? onNotificationTapped;

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final alertId = int.tryParse(response.payload ?? '');
        onNotificationTapped?.call(alertId);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> show({
    required int? alertId,
    required String title,
    required String body,
    required bool isFault,
  }) async {
    await _plugin.show(
      alertId ?? DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: isFault ? Importance.high : Importance.defaultImportance,
          priority: isFault ? Priority.high : Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: isFault,
        ),
      ),
      payload: alertId?.toString(),
    );
  }
}
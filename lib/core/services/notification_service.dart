import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:finora/core/logging/log_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSetting = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSetting = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(android: androidSetting, iOS: iosSetting);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        LogService.d('Notification clicked: ${response.payload}');
      },
    );

    // Request permissions for Android 13+
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
    LogService.i('Notification Service Initialized');
  }

  Future<void> showBudgetWarning({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts_channel',
      'Budget Alerts',
      channelDescription: 'Notifications for budget limits',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFE74C3C), // AppColors.expense
    );
    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(id, title, body, details);
  }
}

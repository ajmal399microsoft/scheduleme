import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../repositories/task_repository.dart';
import 'reminder_schedule.dart';

const dailyRemindersPreferenceKey = 'daily_reminders_enabled';

class TaskReminderService {
  TaskReminderService({FlutterLocalNotificationsPlugin? notifications})
      : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  Future<void>? _initialization;
  bool _enabled = false;
  bool _available = false;

  bool get enabled => _enabled;
  bool get available => _available;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(dailyRemindersPreferenceKey) ?? false;
    _available = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!_available) return;

    try {
      timezone_data.initializeTimeZones();
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(localTimezone));
      await _notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'task_reminders',
              'Task reminders',
              description: 'Reminders for tasks and planned activities.',
              importance: Importance.high,
            ),
          );
    } catch (_) {
      _available = false;
      _enabled = false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    await initialize();
    if (!_available) return false;

    if (enabled) {
      final granted = switch (defaultTargetPlatform) {
        TargetPlatform.android => await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission(),
        TargetPlatform.iOS => await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true),
        _ => false,
      };
      if (granted != true) return false;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(dailyRemindersPreferenceKey, enabled);
    _enabled = enabled;
    if (!enabled) await _notifications.cancelAll();
    return true;
  }

  Future<void> refresh(TaskRepository repository) async {
    await initialize();
    if (!_available) return;
    if (!_enabled) {
      await _notifications.cancelAll();
      return;
    }

    final reminders = buildReminderSchedule(
      tasks: await repository.activeTasks(),
      completions: await repository.history(),
      occurrences: await repository.allOccurrences(),
      now: DateTime.now(),
    );
    await _notifications.cancelAllPendingNotifications();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Task reminders',
        channelDescription: 'Reminders for tasks and planned activities.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final reminder in reminders) {
      await _notifications.zonedSchedule(
        _notificationId(reminder.id),
        reminder.title,
        'Your scheduled task is due.',
        timezone.TZDateTime.from(reminder.scheduledAt, timezone.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: reminder.taskId,
      );
    }
  }

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

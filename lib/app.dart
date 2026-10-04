import 'package:flutter/material.dart';

import 'core/backup/google_drive_backup_coordinator.dart';
import 'core/notifications/task_reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'features/history/history_page.dart';
import 'features/notifications/notification_center_page.dart';
import 'features/settings/settings_page.dart';
import 'features/task_editor/task_editor_page.dart';
import 'features/today/today_page.dart';
import 'repositories/task_repository.dart';

class ScheduleMeApp extends StatelessWidget {
  const ScheduleMeApp(
      {required this.repository,
      required this.backupCoordinator,
      required this.reminderService,
      super.key});

  final TaskRepository repository;
  final GoogleDriveBackupCoordinator backupCoordinator;
  final TaskReminderService reminderService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScheduleMe',
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (_) => TodayPage(
            repository: repository,
            backupCoordinator: backupCoordinator,
            reminderService: reminderService),
        '/tasks/new': (_) => TaskEditorPage(repository: repository),
        '/history': (_) => HistoryPage(repository: repository),
        '/notifications': (_) => NotificationCenterPage(repository: repository),
        '/settings': (_) => SettingsPage(
            backupCoordinator: backupCoordinator,
            repository: repository,
            reminderService: reminderService),
      },
    );
  }
}

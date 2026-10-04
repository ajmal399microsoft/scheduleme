import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/backup/google_drive_backup_coordinator.dart';
import 'core/database/app_database.dart';
import 'core/notifications/task_reminder_service.dart';
import 'repositories/task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final backupCoordinator = GoogleDriveBackupCoordinator(database);
  final reminderService = TaskReminderService();
  await reminderService.initialize();
  late final TaskRepository repository;
  repository = TaskRepository(database,
      onChanged: () => reminderService.refresh(repository));
  await reminderService.refresh(repository);
  unawaited(backupCoordinator.initialize());
  runApp(ScheduleMeApp(
      repository: repository,
      backupCoordinator: backupCoordinator,
      reminderService: reminderService));
}

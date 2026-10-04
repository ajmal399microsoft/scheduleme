import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

import 'database_factory.dart';

class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;

  static const schemaVersion = 8;

  static Future<AppDatabase> open() async {
    await configureDatabaseFactory();
    final databasesPath = await getDatabasesPath();
    final database = await openDatabase(
      path.join(databasesPath, 'schedule_me.db'),
      version: schemaVersion,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onDowngrade: (database, oldVersion, newVersion) async {
        throw StateError(
            'Local database version $oldVersion is newer than this app supports ($newVersion). Data was not changed.');
      },
      onCreate: (database, version) => _applyMigrations(database, 0, version),
      onUpgrade: _applyMigrations,
    );
    return AppDatabase._(database);
  }

  static Future<void> _applyMigrations(
      Database database, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      final sql = await rootBundle.loadString(_migrationPath(version));
      for (final statement in sql.split(';')) {
        final trimmedStatement = statement.trim();
        if (trimmedStatement.isNotEmpty) {
          await database.execute(trimmedStatement);
        }
      }
    }
  }

  static String _migrationPath(int version) {
    if (version == 1) {
      return 'lib/core/database/migrations/001_initial_schema.sql';
    }
    if (version == 2) {
      return 'lib/core/database/migrations/002_completion_status.sql';
    }
    if (version == 3) {
      return 'lib/core/database/migrations/003_task_end_date.sql';
    }
    if (version == 4) {
      return 'lib/core/database/migrations/004_task_occurrences.sql';
    }
    if (version == 5) {
      return 'lib/core/database/migrations/005_generic_task_activity.sql';
    }
    if (version == 6) {
      return 'lib/core/database/migrations/006_completion_anchored_recurrence.sql';
    }
    if (version == 7) {
      return 'lib/core/database/migrations/007_task_reminder_mute.sql';
    }
    if (version == 8) return 'lib/core/database/migrations/008_task_icon.sql';
    throw StateError('Missing migration $version');
  }

  Database get database => _database;

  Future<T> readSnapshot<T>(
          Future<T> Function(Transaction transaction) action) =>
      _database.transaction(action);

  Future<void> close() => _database.close();
}

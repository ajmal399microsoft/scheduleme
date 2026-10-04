import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../files/attachment_store.dart';

class BackupDocument {
  const BackupDocument(
      {required this.createdAt,
      required this.tasks,
      required this.completions,
      required this.occurrences});

  static const formatVersion = 1;

  final DateTime createdAt;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> completions;
  final List<Map<String, Object?>> occurrences;

  static Future<BackupDocument> capture(DatabaseExecutor database,
      {DateTime? createdAt}) async {
    final taskRows = await database.query('tasks', orderBy: 'id ASC');
    final attachmentStore = AttachmentStore();
    final tasks = <Map<String, Object?>>[];
    for (final source in taskRows) {
      final row = Map<String, Object?>.from(source);
      final attachmentData = await attachmentStore.encode(row['attachment_path'] as String?);
      if (attachmentData != null) row['attachment_data'] = attachmentData;
      tasks.add(row);
    }
    final completions = await database.query('completions', orderBy: 'id ASC');
    final occurrences =
        await database.query('task_occurrences', orderBy: 'id ASC');
    return BackupDocument(
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      tasks: tasks,
      completions: completions,
      occurrences: occurrences,
    );
  }

  String encode() => jsonEncode({
        'formatVersion': formatVersion,
        'databaseSchemaVersion': AppDatabase.schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'tables': {
          'tasks': tasks,
          'completions': completions,
          'taskOccurrences': occurrences,
        },
      });

  static BackupDocument decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('This backup is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be an object.');
    }
    if (decoded['formatVersion'] != formatVersion) {
      throw const FormatException(
          'This backup version is not supported by this app.');
    }
    final schemaVersion = decoded['databaseSchemaVersion'];
    if (schemaVersion is! int ||
        schemaVersion < 1 ||
        schemaVersion > AppDatabase.schemaVersion) {
      throw const FormatException(
          'This backup was created by an incompatible database version.');
    }
    final createdAt = DateTime.tryParse(decoded['createdAt'] as String? ?? '');
    if (createdAt == null) {
      throw const FormatException('Backup timestamp is missing or invalid.');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Backup tables are missing.');
    }
    final document = BackupDocument(
      createdAt: createdAt.toUtc(),
      tasks: _rows(tables['tasks'], 'tasks'),
      completions: _rows(tables['completions'], 'completions'),
      occurrences: _rows(tables['taskOccurrences'], 'taskOccurrences'),
    );
    document.validate();
    return document;
  }

  Future<void> restore(Database database) async {
    validate();
    final attachmentStore = AttachmentStore();
    final oldRows = await database.query('tasks', columns: ['attachment_path']);
    final oldAttachments = oldRows.map((row) => row['attachment_path'] as String?).whereType<String>().toSet();
    final restoredFiles = <String>[];
    final restoredTasks = <Map<String, Object?>>[];
    try {
      for (final source in tasks) {
        final row = Map<String, Object?>.from(source);
        final attachmentData = row.remove('attachment_data') as String?;
        final originalPath = row['attachment_path'] as String?;
        if (attachmentData != null) {
          final restoredPath = await attachmentStore.restoreEncoded(attachmentData, row['id']! as String, originalPath);
          row['attachment_path'] = restoredPath;
          restoredFiles.add(restoredPath);
        } else {
          row['attachment_path'] = await attachmentStore.existingPath(originalPath);
        }
        restoredTasks.add(row);
      }
      await database.transaction((transaction) async {
        await transaction.delete('task_occurrences');
        await transaction.delete('completions');
        await transaction.delete('tasks');
        for (final row in restoredTasks) {
          await transaction.insert('tasks', row,
              conflictAlgorithm: ConflictAlgorithm.abort);
        }
        for (final row in completions) {
          await transaction.insert('completions', row,
              conflictAlgorithm: ConflictAlgorithm.abort);
        }
        for (final row in occurrences) {
          await transaction.insert('task_occurrences', row,
              conflictAlgorithm: ConflictAlgorithm.abort);
        }
      });
    } catch (_) {
      for (final file in restoredFiles) {
        await attachmentStore.delete(file);
      }
      rethrow;
    }
    final retainedFiles = restoredTasks.map((row) => row['attachment_path']).whereType<String>().toSet();
    for (final file in oldAttachments.difference(retainedFiles)) {
      await attachmentStore.delete(file);
    }
  }

  void validate() {
    _uniqueIds(tasks, 'tasks');
    _uniqueIds(completions, 'completions');
    _uniqueIds(occurrences, 'taskOccurrences');
    final taskIds = tasks.map((row) => row['id']).toSet();
    for (final row in tasks) {
      _requireString(row, 'title', 'tasks');
      _requireString(row, 'notes', 'tasks');
      _requireInt(row, 'created_at', 'tasks');
      _requireInt(row, 'recurrence_interval', 'tasks', minimum: 1);
      _requireInt(row, 'is_archived', 'tasks', minimum: 0, maximum: 1);
      if (row['reminders_muted'] != null) {
        _requireInt(row, 'reminders_muted', 'tasks', minimum: 0, maximum: 1);
      }
      if (row['icon_key'] != null && row['icon_key'] is! String) {
        throw const FormatException('Backup contains an invalid task icon.');
      }
      if (row['attachment_data'] != null) {
        final attachmentData = row['attachment_data'];
        if (attachmentData is! String || attachmentData.length > 16 * 1024 * 1024) {
          throw const FormatException('Backup contains an invalid task photo.');
        }
        try {
          base64Decode(attachmentData);
        } on FormatException {
          throw const FormatException('Backup contains an invalid task photo.');
        }
      }
      _requireString(row, 'recurrence_frequency', 'tasks');
      if (!const {'once', 'daily', 'weekly', 'monthly', 'yearly'}
          .contains(row['recurrence_frequency'])) {
        throw const FormatException(
            'Backup contains an unknown recurrence type.');
      }
      _requireString(row, 'recurrence_weekdays', 'tasks');
      if (row['repeat_after_completion'] != null) {
        _requireInt(row, 'repeat_after_completion', 'tasks',
            minimum: 0, maximum: 1);
      }
      if (row['group_name'] != null && row['group_name'] is! String) {
        throw const FormatException('Backup contains an invalid task group.');
      }
      if (row['recurrence_end_date'] != null &&
          row['recurrence_end_date'] is! int) {
        throw const FormatException(
            'Backup contains an invalid recurrence end date.');
      }
    }
    for (final row in completions) {
      _requireString(row, 'task_id', 'completions');
      _requireInt(row, 'completed_at', 'completions');
      if (row['is_done'] != null) {
        _requireInt(row, 'is_done', 'completions', minimum: 0, maximum: 1);
      }
      if (row['note'] != null && row['note'] is! String) {
        throw const FormatException(
            'Backup contains an invalid completion note.');
      }
      if (!taskIds.contains(row['task_id'])) {
        throw const FormatException(
            'Backup contains a completion for a missing task.');
      }
    }
    for (final row in occurrences) {
      _requireString(row, 'task_id', 'taskOccurrences');
      _requireInt(row, 'scheduled_at', 'taskOccurrences');
      _requireString(row, 'status', 'taskOccurrences');
      _requireString(row, 'note', 'taskOccurrences');
      if (row['currency_code'] != null && row['currency_code'] is! String) {
        throw const FormatException(
            'Backup contains an invalid activity currency.');
      }
      if (!const {'planned', 'completed', 'missed'}.contains(row['status'])) {
        throw const FormatException(
            'Backup contains an unknown activity status.');
      }
      if (!taskIds.contains(row['task_id'])) {
        throw const FormatException(
            'Backup contains an activity for a missing task.');
      }
      final completedAt = row['completed_at'];
      final amount = row['amount_minor_units'];
      if (completedAt != null && completedAt is! int) {
        throw const FormatException(
            'Backup contains an invalid completion date.');
      }
      if (amount != null && (amount is! int || amount < 0)) {
        throw const FormatException('Backup contains an invalid amount.');
      }
    }
  }

  static List<Map<String, Object?>> _rows(Object? value, String tableName) {
    if (value is! List) {
      throw FormatException('Backup table "$tableName" is missing or invalid.');
    }
    return value.map((item) {
      if (item is! Map) {
        throw FormatException(
            'Backup table "$tableName" contains an invalid row.');
      }
      return Map<String, Object?>.from(item);
    }).toList(growable: false);
  }

  static void _uniqueIds(List<Map<String, Object?>> rows, String tableName) {
    final ids = <Object?>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is! String || id.isEmpty || !ids.add(id)) {
        throw FormatException(
            'Backup table "$tableName" has a missing or duplicate ID.');
      }
    }
  }

  static void _requireString(
      Map<String, Object?> row, String key, String tableName) {
    if (row[key] is! String) {
      throw FormatException(
          'Backup table "$tableName" has an invalid "$key" value.');
    }
  }

  static void _requireInt(
      Map<String, Object?> row, String key, String tableName,
      {int? minimum, int? maximum}) {
    final value = row[key];
    if (value is! int ||
        (minimum != null && value < minimum) ||
        (maximum != null && value > maximum)) {
      throw FormatException(
          'Backup table "$tableName" has an invalid "$key" value.');
    }
  }
}

import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/files/attachment_store.dart';
import '../models/completion.dart';
import '../models/recurrence_rule.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';

class TaskRepository {
  TaskRepository(this._database, {Future<void> Function()? onChanged})
      : _onChanged = onChanged;

  final AppDatabase _database;
  final Future<void> Function()? _onChanged;
  final AttachmentStore _attachmentStore = AttachmentStore();

  Future<List<Task>> dueTasks(DateTime date) async {
    final rows = await _database.database.query(
      'tasks',
      where: 'is_archived = 0',
      orderBy: 'created_at ASC',
    );
    final tasks = rows.map(_taskFromRow).toList();
    final due = <Task>[];
    for (final task in tasks) {
      var anchor = task.createdAt;
      if (task.recurrence.repeatAfterCompletion) {
        final completed = await _database.database.query(
          'task_occurrences',
          columns: ['completed_at'],
          where: 'task_id = ? AND status = ?',
          whereArgs: [task.id, OccurrenceStatus.completed.name],
          orderBy: 'completed_at DESC',
          limit: 1,
        );
        final completedAt = completed.firstOrNull?['completed_at'] as int?;
        if (completedAt != null) {
          anchor = DateTime.fromMillisecondsSinceEpoch(completedAt);
        }
      }
      if (task.recurrence.isDueOn(date, anchor)) due.add(task);
    }
    return due;
  }

  Future<List<Task>> activeTasks() async {
    final rows = await _database.database.query(
      'tasks',
      where: 'is_archived = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(_taskFromRow).toList();
  }

  Future<Task?> taskById(String taskId) async {
    final rows = await _database.database
        .query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1);
    return rows.isEmpty ? null : _taskFromRow(rows.single);
  }

  Future<void> save(Task task) async {
    await _database.database.insert(
      'tasks',
      _taskToRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyChanged();
  }

  Future<void> deleteTask(String taskId) async {
    final rows = await _database.database.query(
      'tasks',
      columns: ['attachment_path'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    await _database.database
        .delete('tasks', where: 'id = ?', whereArgs: [taskId]);
    if (rows.isNotEmpty) {
      try {
        await _attachmentStore
            .delete(rows.single['attachment_path'] as String?);
      } catch (_) {}
    }
    await _notifyChanged();
  }

  Future<void> setTaskRemindersMuted(String taskId, bool muted) async {
    await _database.database.update('tasks', {'reminders_muted': muted ? 1 : 0},
        where: 'id = ?', whereArgs: [taskId]);
    await _notifyChanged();
  }

  Future<List<String>> existingGroups() async {
    final rows = await _database.database.rawQuery(
      "SELECT DISTINCT TRIM(group_name) AS group_name FROM tasks WHERE TRIM(group_name) != '' ORDER BY group_name COLLATE NOCASE",
    );
    return rows.map((row) => row['group_name']! as String).toList();
  }

  Future<List<TaskOccurrence>> occurrences(String taskId) async {
    final rows = await _database.database.query(
      'task_occurrences',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'scheduled_at DESC',
    );
    return rows.map(_occurrenceFromRow).toList();
  }

  Future<List<TaskOccurrence>> allOccurrences() async {
    final rows = await _database.database
        .query('task_occurrences', orderBy: 'scheduled_at DESC');
    return rows.map(_occurrenceFromRow).toList();
  }

  Future<List<TaskOccurrence>> plannedOccurrencesOn(DateTime date) async {
    final start =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end =
        DateTime(date.year, date.month, date.day + 1).millisecondsSinceEpoch;
    final rows = await _database.database.query(
      'task_occurrences',
      where: 'status = ? AND scheduled_at >= ? AND scheduled_at < ?',
      whereArgs: [OccurrenceStatus.planned.name, start, end],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(_occurrenceFromRow).toList();
  }

  Future<void> saveOccurrence(TaskOccurrence occurrence) async {
    await _database.database.insert(
      'task_occurrences',
      _occurrenceToRow(occurrence),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyChanged();
  }

  Future<void> deleteOccurrence(String occurrenceId) async {
    await _database.database
        .delete('task_occurrences', where: 'id = ?', whereArgs: [occurrenceId]);
    await _notifyChanged();
  }

  Future<void> recordCompletion(Task task, DateTime occurrenceAt,
      {required bool isDone, String note = ''}) async {
    final now = DateTime.now();
    await _database.database.transaction((transaction) async {
      await transaction.insert(
          'completions',
          {
            'id': '${task.id}-${occurrenceAt.millisecondsSinceEpoch}',
            'task_id': task.id,
            'completed_at': occurrenceAt.millisecondsSinceEpoch,
            'is_done': isDone ? 1 : 0,
            'note': note,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      final occurrenceId =
          '${task.id}-${occurrenceAt.year}-${occurrenceAt.month}-${occurrenceAt.day}';
      await transaction.insert(
          'task_occurrences',
          {
            'id': occurrenceId,
            'task_id': task.id,
            'scheduled_at': occurrenceAt.millisecondsSinceEpoch,
            'status': isDone
                ? OccurrenceStatus.completed.name
                : OccurrenceStatus.missed.name,
            'completed_at': isDone ? now.millisecondsSinceEpoch : null,
            'amount_minor_units': null,
            'currency_code': 'INR',
            'note': note,
            'created_at': now.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await _notifyChanged();
  }

  Future<void> complete(Task task, DateTime completedAt) =>
      recordCompletion(task, completedAt, isDone: true);

  Future<void> _notifyChanged() async {
    try {
      await _onChanged?.call();
    } catch (_) {}
  }

  Future<List<Completion>> history() async {
    final rows = await _database.database
        .query('completions', orderBy: 'completed_at DESC');
    return rows
        .map((row) => Completion(
              id: row['id']! as String,
              taskId: row['task_id']! as String,
              completedAt: DateTime.fromMillisecondsSinceEpoch(
                  row['completed_at']! as int),
              isDone: (row['is_done'] as int? ?? 1) == 1,
              note: row['note'] as String? ?? '',
            ))
        .toList();
  }

  Task _taskFromRow(Map<String, Object?> row) => Task(
        id: row['id']! as String,
        title: row['title']! as String,
        notes: row['notes']! as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.values
              .byName(row['recurrence_frequency']! as String),
          interval: row['recurrence_interval']! as int,
          weekdays: (row['recurrence_weekdays']! as String)
              .split(',')
              .where((value) => value.isNotEmpty)
              .map(int.parse)
              .toList(),
          endDate: (row['recurrence_end_date'] as int?) == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  row['recurrence_end_date']! as int),
          repeatAfterCompletion:
              (row['repeat_after_completion'] as int? ?? 0) == 1,
        ),
        groupName: row['group_name'] as String? ?? '',
        attachmentPath: row['attachment_path'] as String?,
        isArchived: row['is_archived']! as int == 1,
        remindersMuted: (row['reminders_muted'] as int? ?? 0) == 1,
        iconKey: row['icon_key'] as String? ?? 'task',
      );

  Map<String, Object?> _taskToRow(Task task) => {
        'id': task.id,
        'title': task.title,
        'notes': task.notes,
        'created_at': task.createdAt.millisecondsSinceEpoch,
        'recurrence_frequency': task.recurrence.frequency.name,
        'recurrence_interval': task.recurrence.interval,
        'recurrence_weekdays': task.recurrence.weekdays.join(','),
        'recurrence_end_date': task.recurrence.endDate?.millisecondsSinceEpoch,
        'repeat_after_completion':
            task.recurrence.repeatAfterCompletion ? 1 : 0,
        'group_name': task.groupName,
        'attachment_path': task.attachmentPath,
        'is_archived': task.isArchived ? 1 : 0,
        'reminders_muted': task.remindersMuted ? 1 : 0,
        'icon_key': task.iconKey,
      };

  TaskOccurrence _occurrenceFromRow(Map<String, Object?> row) => TaskOccurrence(
        id: row['id']! as String,
        taskId: row['task_id']! as String,
        scheduledAt:
            DateTime.fromMillisecondsSinceEpoch(row['scheduled_at']! as int),
        status: OccurrenceStatus.values.byName(row['status']! as String),
        completedAt: (row['completed_at'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['completed_at']! as int),
        amountMinorUnits:
            (row['amount_minor_units'] as int?) ?? (row['cost_paise'] as int?),
        currencyCode: row['currency_code'] as String? ?? 'INR',
        note: row['note']! as String,
      );

  Map<String, Object?> _occurrenceToRow(TaskOccurrence occurrence) => {
        'id': occurrence.id,
        'task_id': occurrence.taskId,
        'scheduled_at': occurrence.scheduledAt.millisecondsSinceEpoch,
        'status': occurrence.status.name,
        'completed_at': occurrence.completedAt?.millisecondsSinceEpoch,
        'amount_minor_units': occurrence.amountMinorUnits,
        'currency_code': occurrence.currencyCode,
        'note': occurrence.note,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/core/backup/backup_document.dart';
import 'package:schedule_me/core/database/app_database.dart';

void main() {
  final task = <String, Object?>{
    'id': 'nails',
    'title': 'Nail cutting',
    'notes': 'Scissors',
    'created_at': 1780000000000,
    'recurrence_frequency': 'weekly',
    'recurrence_interval': 2,
    'recurrence_weekdays': '',
    'recurrence_end_date': null,
    'repeat_after_completion': 1,
    'group_name': 'Personal care',
    'attachment_path': null,
    'is_archived': 0,
    'reminders_muted': 1,
    'icon_key': 'health',
  };

  final completion = <String, Object?>{
    'id': 'nails-done',
    'task_id': 'nails',
    'completed_at': 1780000100000,
    'is_done': 1,
    'note': 'Done',
  };

  final occurrence = <String, Object?>{
    'id': 'nails-visit',
    'task_id': 'nails',
    'scheduled_at': 1780000000000,
    'status': 'completed',
    'completed_at': 1780000100000,
    'amount_minor_units': 0,
    'currency_code': 'INR',
    'note': 'Done',
    'created_at': 1780000100000,
  };

  String encode(
          {int formatVersion = BackupDocument.formatVersion,
          int schemaVersion = AppDatabase.schemaVersion,
          List<Map<String, Object?>>? tasks,
          List<Map<String, Object?>>? completions,
          List<Map<String, Object?>>? occurrences}) =>
      jsonEncode({
        'formatVersion': formatVersion,
        'databaseSchemaVersion': schemaVersion,
        'createdAt': '2026-04-01T10:00:00.000Z',
        'tables': {
          'tasks': tasks ?? [task],
          'completions': completions ?? [completion],
          'taskOccurrences': occurrences ?? [occurrence],
        },
      });

  test(
      'valid backup round-trips task groups, recurrence, completions, and occurrences',
      () {
    final decoded = BackupDocument.decode(encode());

    expect(decoded.tasks.single['group_name'], 'Personal care');
    expect(decoded.tasks.single['repeat_after_completion'], 1);
    expect(decoded.tasks.single['reminders_muted'], 1);
    expect(decoded.tasks.single['icon_key'], 'health');
    expect(decoded.completions.single['note'], 'Done');
    expect(decoded.occurrences.single['currency_code'], 'INR');
    expect(decoded.createdAt, DateTime.utc(2026, 4, 1, 10));
  });

  test('rejects unsupported backup format versions', () {
    expect(() => BackupDocument.decode(encode(formatVersion: 99)),
        throwsFormatException);
  });

  test('accepts embedded task photo data', () {
    final decoded = BackupDocument.decode(encode(tasks: [
      {...task, 'attachment_data': 'aGVsbG8='},
    ]));

    expect(decoded.tasks.single['attachment_data'], 'aGVsbG8=');
  });

  test('rejects invalid embedded task photo data', () {
    expect(
      () => BackupDocument.decode(encode(tasks: [
        {...task, 'attachment_data': 'not-base64!'},
      ])),
      throwsFormatException,
    );
  });

  test('rejects duplicate task IDs', () {
    expect(() => BackupDocument.decode(encode(tasks: [task, task])),
        throwsFormatException);
  });

  test('rejects activity records that refer to a missing task', () {
    final orphan = {...occurrence, 'task_id': 'missing'};
    expect(() => BackupDocument.decode(encode(occurrences: [orphan])),
        throwsFormatException);
  });

  test('rejects unsupported recurrence values', () {
    final invalid = {...task, 'recurrence_frequency': 'every-other-moon'};
    expect(() => BackupDocument.decode(encode(tasks: [invalid])),
        throwsFormatException);
  });

  test('accepts an older schema with fields added by later migrations', () {
    final oldTask = Map<String, Object?>.from(task)
      ..remove('group_name')
      ..remove('repeat_after_completion')
      ..remove('reminders_muted')
      ..remove('icon_key');
    final oldCompletion = Map<String, Object?>.from(completion)
      ..remove('is_done')
      ..remove('note');
    final oldOccurrence = Map<String, Object?>.from(occurrence)
      ..remove('amount_minor_units')
      ..remove('currency_code');

    final decoded = BackupDocument.decode(encode(
      schemaVersion: 4,
      tasks: [oldTask],
      completions: [oldCompletion],
      occurrences: [oldOccurrence],
    ));

    expect(decoded.tasks.single.containsKey('group_name'), isFalse);
    expect(decoded.tasks.single.containsKey('icon_key'), isFalse);
    expect(decoded.occurrences.single.containsKey('currency_code'), isFalse);
  });
}

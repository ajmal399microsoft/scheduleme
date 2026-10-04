import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/models/completion.dart';
import 'package:schedule_me/models/pending_task_occurrence.dart';
import 'package:schedule_me/models/recurrence_rule.dart';
import 'package:schedule_me/models/task.dart';
import 'package:schedule_me/models/task_occurrence.dart';

void main() {
  final today = DateTime(2026, 10, 2, 12);

  test('keeps a past one-time task pending until completed', () {
    final task = _task(
        frequency: RecurrenceFrequency.once,
        createdAt: DateTime(2026, 10, 1, 9));

    expect(_next(task, asOf: today), DateTime(2026, 10, 1, 9));
  });

  test('keeps a one-time task overdue even when its date is many years old',
      () {
    final task = _task(
        frequency: RecurrenceFrequency.once,
        createdAt: DateTime(2000, 1, 1, 9));

    expect(_next(task, asOf: today), DateTime(2000, 1, 1, 9));
  });

  test('does not resolve a past date marked not done', () {
    final task = _task(
        frequency: RecurrenceFrequency.daily,
        createdAt: DateTime(2026, 10, 1, 9));
    final missed = TaskOccurrence(
      id: 'missed',
      taskId: task.id,
      scheduledAt: DateTime(2026, 10, 1, 9),
      status: OccurrenceStatus.missed,
    );

    expect(_next(task, asOf: today, occurrences: [missed]),
        DateTime(2026, 10, 1, 9));
  });

  test('moves to the next recurrence after the current due date is completed',
      () {
    final task = _task(
        frequency: RecurrenceFrequency.daily,
        createdAt: DateTime(2026, 10, 2, 9));
    final completed = Completion(
        id: 'done', taskId: task.id, completedAt: DateTime(2026, 10, 2, 9));

    expect(
        _next(task, asOf: today, includeFuture: true, completions: [completed]),
        DateTime(2026, 10, 3, 9));
  });

  test('does not expose a future task as pending yet', () {
    final task = _task(
        frequency: RecurrenceFrequency.once,
        createdAt: DateTime(2026, 10, 3, 9));

    expect(_next(task, asOf: today), isNull);
    expect(_next(task, asOf: today, includeFuture: true),
        DateTime(2026, 10, 3, 9));
  });
}

DateTime? _next(Task task,
        {required DateTime asOf,
        bool includeFuture = false,
        List<Completion> completions = const [],
        List<TaskOccurrence> occurrences = const []}) =>
    nextPendingOccurrence(
        task: task,
        completions: completions,
        occurrences: occurrences,
        asOf: asOf,
        includeFuture: includeFuture);

Task _task(
        {required RecurrenceFrequency frequency,
        required DateTime createdAt}) =>
    Task(
      id: 'task',
      title: 'Test task',
      notes: '',
      createdAt: createdAt,
      recurrence: RecurrenceRule(frequency: frequency),
    );

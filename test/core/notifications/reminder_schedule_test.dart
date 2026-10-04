import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/core/notifications/reminder_schedule.dart';
import 'package:schedule_me/models/completion.dart';
import 'package:schedule_me/models/recurrence_rule.dart';
import 'package:schedule_me/models/task.dart';
import 'package:schedule_me/models/task_occurrence.dart';

void main() {
  final now = DateTime(2026, 5, 10, 8);

  test('schedules one morning reminder that repeats for each unresolved task',
      () {
    final task = _task(createdAt: DateTime(2026, 5, 9, 9, 30));

    final reminders = buildReminderSchedule(
        tasks: [task], completions: [], occurrences: [], now: now);

    expect(reminders, hasLength(1));
    expect(reminders.single.scheduledAt, DateTime(2026, 5, 11, 8));
  });

  test('keeps overdue work eligible after it was marked not done', () {
    final task = _task(createdAt: DateTime(2026, 5, 9, 9));
    final occurrences = [
      _occurrence(task, DateTime(2026, 5, 10), OccurrenceStatus.missed),
    ];

    final reminders = buildReminderSchedule(
        tasks: [task], completions: [], occurrences: occurrences, now: now);

    expect(reminders.single.scheduledAt, DateTime(2026, 5, 11, 8));
  });

  test('uses repeat-after-completion anchor to find the next morning reminder',
      () {
    final task = _task(
      createdAt: DateTime(2026, 5, 9, 9),
      recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: 3,
          repeatAfterCompletion: true),
    );
    final occurrence = TaskOccurrence(
      id: 'done',
      taskId: task.id,
      scheduledAt: DateTime(2026, 5, 9, 9),
      status: OccurrenceStatus.completed,
      completedAt: DateTime(2026, 5, 9, 15),
    );

    final reminders = buildReminderSchedule(
        tasks: [task], completions: [], occurrences: [occurrence], now: now);

    expect(reminders.single.scheduledAt, DateTime(2026, 5, 12, 8));
  });

  test('does not remind after all due dates are completed', () {
    final task = _task(
        createdAt: DateTime(2026, 5, 10, 9),
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.once));
    final completion = Completion(
        id: 'done', taskId: task.id, completedAt: DateTime(2026, 5, 10, 9));

    final reminders = buildReminderSchedule(
        tasks: [task], completions: [completion], occurrences: [], now: now);

    expect(reminders, isEmpty);
  });

  test('omits archived and individually muted tasks', () {
    final tasks = [
      _task(id: 'active', createdAt: DateTime(2026, 5, 9, 9)),
      _task(
          id: 'archived', createdAt: DateTime(2026, 5, 9, 9), isArchived: true),
      _task(
          id: 'muted',
          createdAt: DateTime(2026, 5, 9, 9),
          remindersMuted: true),
    ];

    final reminders = buildReminderSchedule(
        tasks: tasks, completions: [], occurrences: [], now: now);

    expect(reminders.map((item) => item.id), ['active']);
  });
}

Task _task({
  String id = 'task',
  required DateTime createdAt,
  RecurrenceRule recurrence =
      const RecurrenceRule(frequency: RecurrenceFrequency.daily),
  bool isArchived = false,
  bool remindersMuted = false,
}) =>
    Task(
      id: id,
      title: 'Water plants',
      notes: '',
      createdAt: createdAt,
      recurrence: recurrence,
      isArchived: isArchived,
      remindersMuted: remindersMuted,
    );

TaskOccurrence _occurrence(Task task, DateTime at, OccurrenceStatus status) =>
    TaskOccurrence(
      id: '${task.id}-${at.day}',
      taskId: task.id,
      scheduledAt: at,
      status: status,
    );

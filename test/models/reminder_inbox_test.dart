import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/models/completion.dart';
import 'package:schedule_me/models/recurrence_rule.dart';
import 'package:schedule_me/models/reminder_inbox.dart';
import 'package:schedule_me/models/task.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12);

  test('shows overdue task as open and past due dates in reminder history', () {
    final task = _task(DateTime(2026, 9, 30, 9));

    final inbox = buildReminderInbox(tasks: [task], completions: [], occurrences: [], now: now);

    expect(inbox.openItems.single.scheduledAt, DateTime(2026, 9, 30, 9));
    expect(inbox.openItems.single.isOverdueAt(now), isTrue);
    expect(inbox.history.map((item) => item.scheduledAt), [
      DateTime(2026, 10, 1, 9),
      DateTime(2026, 9, 30, 9),
    ]);
  });

  test('moves a completed due date to history without retaining it as open', () {
    final task = _task(DateTime(2026, 10, 1, 9), frequency: RecurrenceFrequency.once);
    final completion = Completion(id: 'done', taskId: task.id, completedAt: DateTime(2026, 10, 1, 9));

    final inbox = buildReminderInbox(tasks: [task], completions: [completion], occurrences: [], now: now);

    expect(inbox.openItems, isEmpty);
    expect(inbox.history.single.completed, isTrue);
  });

  test('does not include future tasks in open items or past history', () {
    final task = _task(DateTime(2026, 10, 3, 9), frequency: RecurrenceFrequency.once);

    final inbox = buildReminderInbox(tasks: [task], completions: [], occurrences: [], now: now);

    expect(inbox.openItems, isEmpty);
    expect(inbox.history, isEmpty);
  });
}

Task _task(DateTime createdAt, {RecurrenceFrequency frequency = RecurrenceFrequency.daily}) => Task(
      id: 'task',
      title: 'Water plants',
      notes: '',
      createdAt: createdAt,
      recurrence: RecurrenceRule(frequency: frequency),
    );
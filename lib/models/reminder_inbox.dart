import 'completion.dart';
import 'pending_task_occurrence.dart';
import 'task.dart';
import 'task_occurrence.dart';

class ReminderInboxEntry {
  const ReminderInboxEntry({
    required this.task,
    required this.scheduledAt,
    required this.completed,
  });

  final Task task;
  final DateTime scheduledAt;
  final bool completed;

  bool isOverdueAt(DateTime now) =>
      scheduledAt.isBefore(DateTime(now.year, now.month, now.day));
}

class ReminderInboxSnapshot {
  const ReminderInboxSnapshot({required this.openItems, required this.history});

  final List<ReminderInboxEntry> openItems;
  final List<ReminderInboxEntry> history;
}

ReminderInboxSnapshot buildReminderInbox({
  required List<Task> tasks,
  required List<Completion> completions,
  required List<TaskOccurrence> occurrences,
  required DateTime now,
}) {
  final openItems = <ReminderInboxEntry>[];
  final history = <ReminderInboxEntry>[];
  final today = DateTime(now.year, now.month, now.day);

  for (final task in tasks.where((item) => !item.isArchived)) {
    final taskCompletions = completions.where((item) => item.taskId == task.id).toList();
    final taskOccurrences = occurrences.where((item) => item.taskId == task.id).toList();
    final pendingAt = nextPendingOccurrence(
      task: task,
      completions: taskCompletions,
      occurrences: taskOccurrences,
      asOf: now,
    );
    if (pendingAt != null) {
      openItems.add(ReminderInboxEntry(task: task, scheduledAt: pendingAt, completed: false));
    }

    final completedDates = <String>{};
    final completedAtByDate = <String, DateTime>{};
    for (final completion in taskCompletions.where((item) => item.isDone)) {
      completedDates.add(_dateKey(completion.completedAt));
      completedAtByDate[_dateKey(completion.completedAt)] = completion.completedAt;
    }
    for (final occurrence in taskOccurrences.where((item) => item.status == OccurrenceStatus.completed)) {
      final key = _dateKey(occurrence.scheduledAt);
      completedDates.add(key);
      completedAtByDate[key] = occurrence.completedAt ?? occurrence.scheduledAt;
    }

    var anchor = task.createdAt;
    final start = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    for (var day = start; day.isBefore(today); day = day.add(const Duration(days: 1))) {
      if (task.recurrence.isDueOn(day, anchor)) {
        final scheduledAt = DateTime(day.year, day.month, day.day, task.createdAt.hour, task.createdAt.minute);
        history.add(ReminderInboxEntry(
          task: task,
          scheduledAt: scheduledAt,
          completed: completedDates.contains(_dateKey(day)),
        ));
      }
      if (task.recurrence.repeatAfterCompletion) {
        anchor = completedAtByDate[_dateKey(day)] ?? anchor;
      }
    }

    for (final completion in taskCompletions) {
      final date = DateTime(completion.completedAt.year, completion.completedAt.month, completion.completedAt.day);
      if (date.isBefore(today) && history.every((item) => item.task.id != task.id || !_sameDay(item.scheduledAt, completion.completedAt))) {
        history.add(ReminderInboxEntry(task: task, scheduledAt: completion.completedAt, completed: completion.isDone));
      }
    }
  }

  openItems.sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
  history.sort((left, right) => right.scheduledAt.compareTo(left.scheduledAt));
  return ReminderInboxSnapshot(openItems: openItems, history: history);
}

String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;
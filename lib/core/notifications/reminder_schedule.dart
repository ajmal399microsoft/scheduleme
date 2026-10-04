import '../../models/task.dart';
import '../../models/completion.dart';
import '../../models/pending_task_occurrence.dart';
import '../../models/task_occurrence.dart';

class ReminderScheduleItem {
  const ReminderScheduleItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.scheduledAt,
  });

  final String id;
  final String taskId;
  final String title;
  final DateTime scheduledAt;
}

List<ReminderScheduleItem> buildReminderSchedule({
  required List<Task> tasks,
  required List<Completion> completions,
  required List<TaskOccurrence> occurrences,
  required DateTime now,
  int reminderHour = 8,
  int horizonDays = 30,
}) {
  final reminders = <ReminderScheduleItem>[];
  final today = DateTime(now.year, now.month, now.day);
  for (final task
      in tasks.where((item) => !item.isArchived && !item.remindersMuted)) {
    final pendingAt = nextPendingOccurrence(
      task: task,
      completions: completions,
      occurrences: occurrences,
      asOf: now,
      includeFuture: true,
      searchDays: horizonDays,
    );
    if (pendingAt == null) {
      continue;
    }
    var reminderDate = DateTime(pendingAt.year, pendingAt.month, pendingAt.day);
    if (reminderDate.isBefore(today)) {
      reminderDate = today;
    }
    var scheduledAt = DateTime(
        reminderDate.year, reminderDate.month, reminderDate.day, reminderHour);
    if (!scheduledAt.isAfter(now)) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }
    reminders.add(ReminderScheduleItem(
      id: task.id,
      taskId: task.id,
      title: task.title,
      scheduledAt: scheduledAt,
    ));
  }

  reminders
      .sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
  return reminders;
}

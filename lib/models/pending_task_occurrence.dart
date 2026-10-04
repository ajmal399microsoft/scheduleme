import 'completion.dart';
import 'task.dart';
import 'task_occurrence.dart';

DateTime? nextPendingOccurrence({
  required Task task,
  required List<Completion> completions,
  required List<TaskOccurrence> occurrences,
  required DateTime asOf,
  bool includeFuture = false,
  int searchDays = 36500,
}) {
  final completedDates = <String>{};
  final completionTimes = <DateTime>[];
  for (final completion
      in completions.where((item) => item.taskId == task.id && item.isDone)) {
    completedDates.add(_dateKey(completion.completedAt));
    completionTimes.add(completion.completedAt);
  }
  for (final occurrence in occurrences.where((item) =>
      item.taskId == task.id && item.status == OccurrenceStatus.completed)) {
    completedDates.add(_dateKey(occurrence.scheduledAt));
    if (occurrence.completedAt != null) {
      completionTimes.add(occurrence.completedAt!);
    }
  }

  completionTimes.sort((left, right) => right.compareTo(left));
  final anchor =
      task.recurrence.repeatAfterCompletion && completionTimes.isNotEmpty
          ? completionTimes.first
          : task.createdAt;
  final today = DateTime(asOf.year, asOf.month, asOf.day);
  final start =
      DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);

  DateTime? oldestOverdue;
  for (var offset = 0; offset <= searchDays; offset++) {
    final day = today.subtract(Duration(days: offset));
    if (day.isBefore(start)) {
      break;
    }
    if (task.recurrence.isDueOn(day, anchor) &&
        !completedDates.contains(_dateKey(day))) {
      oldestOverdue = DateTime(day.year, day.month, day.day,
          task.createdAt.hour, task.createdAt.minute);
    }
  }
  if (oldestOverdue != null) {
    return oldestOverdue;
  }
  if (!includeFuture) {
    return null;
  }

  for (var offset = 1; offset <= searchDays; offset++) {
    final day = today.add(Duration(days: offset));
    if (task.recurrence.endDate != null &&
        day.isAfter(DateTime(task.recurrence.endDate!.year,
            task.recurrence.endDate!.month, task.recurrence.endDate!.day))) {
      break;
    }
    if (task.recurrence.isDueOn(day, anchor) &&
        !completedDates.contains(_dateKey(day))) {
      return DateTime(day.year, day.month, day.day, task.createdAt.hour,
          task.createdAt.minute);
    }
  }
  return null;
}

String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

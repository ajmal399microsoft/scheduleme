import 'recurrence_rule.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    required this.recurrence,
    this.groupName = '',
    this.attachmentPath,
    this.isArchived = false,
    this.remindersMuted = false,
    this.iconKey = 'task',
  });

  final String id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final RecurrenceRule recurrence;
  final String groupName;
  final String? attachmentPath;
  final bool isArchived;
  final bool remindersMuted;
  final String iconKey;
}

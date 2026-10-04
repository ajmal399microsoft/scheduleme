enum OccurrenceStatus { planned, completed, missed }

class TaskOccurrence {
  const TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.scheduledAt,
    required this.status,
    this.completedAt,
    this.amountMinorUnits,
    this.currencyCode = 'INR',
    this.note = '',
  });

  final String id;
  final String taskId;
  final DateTime scheduledAt;
  final OccurrenceStatus status;
  final DateTime? completedAt;
  final int? amountMinorUnits;
  final String currencyCode;
  final String note;
}
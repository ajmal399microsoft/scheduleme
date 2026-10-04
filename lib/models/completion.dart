class Completion {
  const Completion({
    required this.id,
    required this.taskId,
    required this.completedAt,
    this.isDone = true,
    this.note = '',
  });

  final String id;
  final String taskId;
  final DateTime completedAt;

  final bool isDone;
  final String note;
}

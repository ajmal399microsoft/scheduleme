import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/models/task_occurrence.dart';

void main() {
  test('a task can hold separate planned and completed visit records', () {
    const taskId = 'car-123-service';
    final planned = TaskOccurrence(
      id: 'visit-next',
      taskId: taskId,
      scheduledAt: DateTime(2026, 10, 12, 9, 30),
      status: OccurrenceStatus.planned,
      note: 'Book the dealership',
    );
    final completed = TaskOccurrence(
      id: 'visit-done',
      taskId: taskId,
      scheduledAt: DateTime(2026, 6, 8, 10),
      status: OccurrenceStatus.completed,
      completedAt: DateTime(2026, 6, 8, 11, 15),
      amountMinorUnits: 500000,
      note: 'Oil and filter changed',
    );

    expect(planned.taskId, completed.taskId);
    expect(planned.id, isNot(completed.id));
    expect(planned.status, OccurrenceStatus.planned);
    expect(completed.completedAt, DateTime(2026, 6, 8, 11, 15));
    expect(completed.amountMinorUnits, 500000);
    expect(completed.note, 'Oil and filter changed');
  });

  test('cost is represented in integer paise to avoid floating point storage', () {
    final occurrence = TaskOccurrence(
      id: 'visit',
      taskId: 'car-123-service',
      scheduledAt: DateTime(2026, 6, 8),
      status: OccurrenceStatus.completed,
      amountMinorUnits: 500125,
    );

    expect(occurrence.amountMinorUnits, 500125);
  });
}
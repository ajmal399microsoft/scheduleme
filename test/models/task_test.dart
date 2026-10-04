import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/models/recurrence_rule.dart';
import 'package:schedule_me/models/task.dart';

void main() {
  test('tasks can be assigned a user-defined dashboard group', () {
    final task = Task(
      id: 'nails',
      title: 'Nail cutting',
      notes: 'Use nail scissors',
      createdAt: DateTime(2026, 1, 5, 18, 30),
      recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly, interval: 2),
      groupName: 'Personal care',
      remindersMuted: true,
      iconKey: 'health',
    );

    expect(task.groupName, 'Personal care');
    expect(task.recurrence.interval, 2);
    expect(task.recurrence.frequency, RecurrenceFrequency.weekly);
    expect(task.remindersMuted, isTrue);
    expect(task.iconKey, 'health');
  });
}

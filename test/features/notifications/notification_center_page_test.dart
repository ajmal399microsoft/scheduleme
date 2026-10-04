import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/features/notifications/notification_center_page.dart';
import 'package:schedule_me/models/reminder_inbox.dart';
import 'package:schedule_me/models/recurrence_rule.dart';
import 'package:schedule_me/models/task.dart';

void main() {
  testWidgets('shows open and past reminders and opens the selected task', (tester) async {
    final task = Task(
      id: 'plants',
      title: 'Water plants',
      notes: '',
      createdAt: DateTime(2026, 10, 1, 9),
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      groupName: 'Home',
      iconKey: 'home',
    );
    Task? openedTask;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReminderInboxView(
          snapshot: ReminderInboxSnapshot(
            openItems: [ReminderInboxEntry(task: task, scheduledAt: DateTime(2026, 10, 1, 9), completed: false)],
            history: [ReminderInboxEntry(task: task, scheduledAt: DateTime(2026, 9, 30, 9), completed: true)],
          ),
          onOpenTask: (value) => openedTask = value,
        ),
      ),
    ));

    expect(find.text('Open items'), findsOneWidget);
    expect(find.text('Past reminders'), findsOneWidget);
    expect(find.text('Water plants'), findsNWidgets(2));
    await tester.tap(find.text('Water plants').first);
    expect(openedTask, task);
  });
}
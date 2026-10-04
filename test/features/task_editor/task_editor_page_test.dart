import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/features/task_editor/task_editor_page.dart';
import 'package:schedule_me/models/task.dart';
import 'package:schedule_me/repositories/task_repository.dart';

void main() {
  testWidgets('suggests an existing group and saves the selected value',
      (tester) async {
    final repository = _FakeTaskRepository(['Home care', 'Personal']);

    await tester
        .pumpWidget(MaterialApp(home: TaskEditorPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Water plants');
    await tester.enterText(find.byType(TextFormField).at(1), 'home');
    await tester.pumpAndSettle();

    expect(find.text('Home care'), findsOneWidget);
    await tester.tap(find.text('Home care'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Health'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    expect(repository.savedTask?.title, 'Water plants');
    expect(repository.savedTask?.groupName, 'Home care');
    expect(repository.savedTask?.iconKey, 'health');
  });
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(this.groups);

  final List<String> groups;
  Task? savedTask;

  @override
  Future<List<String>> existingGroups() async => groups;

  @override
  Future<void> save(Task task) async {
    savedTask = task;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:flutter/material.dart';

import '../../models/completion.dart';
import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../tasks/task_artwork.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.repository, super.key});

  final TaskRepository repository;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<_HistoryData> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = Future.wait([
      widget.repository.activeTasks(),
      widget.repository.history(),
    ]).then((values) => _HistoryData(
          values[0] as List<Task>,
          values[1] as List<Completion>,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<_HistoryData>(
        future: _history,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!.entries;
          if (entries.isEmpty) {
            return const Center(child: Text('No recurring history yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isDone = entry.completion?.isDone == true;
              final note = entry.completion?.note ?? '';
              return ListTile(
                leading: TaskArtwork(task: entry.task, size: 42),
                title: Text(entry.task.title),
                subtitle: Text(
                    '${_dateLabel(context, entry.date)} · ${isDone ? 'Done' : 'Not done'}${note.isNotEmpty ? '\n$note' : ''}'),
                isThreeLine: note.isNotEmpty,
                trailing: Icon(isDone ? Icons.check_circle : Icons.cancel,
                    color: isDone ? Colors.green : Colors.red),
              );
            },
          );
        },
      ),
    );
  }

  String _dateLabel(BuildContext context, DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at ${TimeOfDay.fromDateTime(date).format(context)}';
}

class _HistoryData {
  _HistoryData(this.tasks, this.completions);

  final List<Task> tasks;
  final List<Completion> completions;

  List<_HistoryEntry> get entries {
    final today = DateTime.now();
    final result = <_HistoryEntry>[];
    for (final task in tasks) {
      final start = DateTime(
          task.createdAt.year, task.createdAt.month, task.createdAt.day);
      var date = start;
      while (!date.isAfter(today)) {
        if (task.recurrence.isDueOn(date, task.createdAt)) {
          final occurrence = DateTime(date.year, date.month, date.day,
              task.createdAt.hour, task.createdAt.minute);
          Completion? completion;
          for (final item in completions) {
            if (item.taskId == task.id &&
                _sameOccurrence(item.completedAt, occurrence)) {
              completion = item;
              break;
            }
          }
          result.add(_HistoryEntry(task, occurrence, completion));
        }
        date = date.add(const Duration(days: 1));
      }
    }
    for (final completion in completions) {
      final task =
          tasks.where((item) => item.id == completion.taskId).firstOrNull;
      if (task == null ||
          result.any((entry) =>
              entry.task.id == task.id &&
              _sameOccurrence(entry.date, completion.completedAt))) {
        continue;
      }
      result.add(_HistoryEntry(task, completion.completedAt, completion));
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static bool _sameOccurrence(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _HistoryEntry {
  const _HistoryEntry(this.task, this.date, this.completion);

  final Task task;
  final DateTime date;
  final Completion? completion;
}

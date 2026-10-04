import 'package:flutter/material.dart';

import '../../models/completion.dart';
import '../../models/reminder_inbox.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../repositories/task_repository.dart';
import '../tasks/task_artwork.dart';
import '../task_detail/task_detail_page.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({required this.repository, super.key});

  final TaskRepository repository;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  late Future<ReminderInboxSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _snapshot = Future.wait([
      widget.repository.activeTasks(),
      widget.repository.history(),
      widget.repository.allOccurrences(),
    ]).then((values) => buildReminderInbox(
          tasks: values[0] as List<Task>,
          completions: values[1] as List<Completion>,
          occurrences: values[2] as List<TaskOccurrence>,
          now: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reminders')),
        body: FutureBuilder<ReminderInboxSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Could not load reminders: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: ReminderInboxView(
                snapshot: snapshot.data!,
                onOpenTask: (task) async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TaskDetailPage(
                              repository: widget.repository, task: task)));
                  if (mounted) setState(_reload);
                },
              ),
            );
          },
        ),
      );
}

class ReminderInboxView extends StatelessWidget {
  const ReminderInboxView(
      {required this.snapshot, required this.onOpenTask, super.key});

  final ReminderInboxSnapshot snapshot;
  final ValueChanged<Task> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
              child: _sectionHeading(
                  context, 'Open items', snapshot.openItems.length)),
        ),
        if (snapshot.openItems.isEmpty)
          const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                  child: _EmptySection(message: 'You’re all caught up.')))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
              (context, index) => _ReminderTile(
                  entry: snapshot.openItems[index],
                  now: now,
                  onTap: () => onOpenTask(snapshot.openItems[index].task)),
              childCount: snapshot.openItems.length,
            )),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          sliver: SliverToBoxAdapter(
              child: _sectionHeading(
                  context, 'Past reminders', snapshot.history.length)),
        ),
        if (snapshot.history.isEmpty)
          const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(
                  child: _EmptySection(
                      message: 'Past due dates will appear here.')))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
              (context, index) => _ReminderTile(
                  entry: snapshot.history[index],
                  now: now,
                  history: true,
                  onTap: () => onOpenTask(snapshot.history[index].task)),
              childCount: snapshot.history.length,
            )),
          ),
      ],
    );
  }

  Widget _sectionHeading(BuildContext context, String title, int count) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          Text('$count', style: Theme.of(context).textTheme.labelLarge),
        ]),
      );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile(
      {required this.entry,
      required this.now,
      required this.onTap,
      this.history = false});

  final ReminderInboxEntry entry;
  final DateTime now;
  final VoidCallback onTap;
  final bool history;

  @override
  Widget build(BuildContext context) {
    final overdue = entry.isOverdueAt(now) && !entry.completed;
    final color = overdue ? Theme.of(context).colorScheme.error : null;
    final date = entry.scheduledAt;
    final dateText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: TaskArtwork(task: entry.task, size: 44),
        title: Text(entry.task.title,
            style: color == null ? null : TextStyle(color: color)),
        subtitle: Text(
            '${history ? entry.completed ? 'Completed' : overdue ? 'Overdue' : 'Reminder' : overdue ? 'Overdue' : 'Due'} · $dateText'),
        trailing: Icon(
            history
                ? entry.completed
                    ? Icons.check_circle_outline
                    : Icons.history
                : Icons.chevron_right,
            color: color),
        onTap: onTap,
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      );
}

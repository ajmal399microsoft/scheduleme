import 'package:flutter/material.dart';

import '../../core/backup/google_drive_backup_coordinator.dart';
import '../../core/notifications/task_reminder_service.dart';
import '../../models/completion.dart';
import '../../models/pending_task_occurrence.dart';
import '../../models/reminder_inbox.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../repositories/task_repository.dart';
import '../task_detail/task_detail_page.dart';
import '../task_editor/task_editor_page.dart';
import '../tasks/task_artwork.dart';

class TodayPage extends StatefulWidget {
  const TodayPage(
      {required this.repository,
      required this.backupCoordinator,
      required this.reminderService,
      super.key});

  final TaskRepository repository;
  final GoogleDriveBackupCoordinator backupCoordinator;
  final TaskReminderService reminderService;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late DateTime _selectedDate;
  late Future<_AgendaData> _agenda;
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _showAllTasks = true;
  int _lastRestoreRevision = 0;

  @override
  void initState() {
    super.initState();
    _lastRestoreRevision = widget.backupCoordinator.restoreRevision;
    widget.backupCoordinator.addListener(_onBackupCoordinatorChanged);
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _reload();
  }

  @override
  void dispose() {
    widget.backupCoordinator.removeListener(_onBackupCoordinatorChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onBackupCoordinatorChanged() {
    final revision = widget.backupCoordinator.restoreRevision;
    if (revision == _lastRestoreRevision) return;
    _lastRestoreRevision = revision;
    widget.reminderService.refresh(widget.repository);
    if (mounted) setState(_reload);
  }

  void _reload() {
    _agenda = Future.wait([
      widget.repository.dueTasks(_selectedDate),
      widget.repository.history(),
      widget.repository.plannedOccurrencesOn(_selectedDate),
      widget.repository.activeTasks(),
      widget.repository.allOccurrences(),
    ]).then((values) => _AgendaData(
          values[0] as List<Task>,
          values[1] as List<Completion>,
          values[2] as List<TaskOccurrence>,
          values[3] as List<Task>,
          values[4] as List<TaskOccurrence>,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Search tasks', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              )
            : const Text('ScheduleMe'),
        actions: [
          FutureBuilder<_AgendaData>(
            future: _agenda,
            builder: (context, snapshot) {
              final count = snapshot.hasData
                  ? buildReminderInbox(
                      tasks: snapshot.data!.allTasks,
                      completions: snapshot.data!.completions,
                      occurrences: snapshot.data!.allOccurrences,
                      now: DateTime.now(),
                    ).openItems.length
                  : 0;
              return IconButton(
                tooltip: count == 0 ? 'Reminders' : 'Reminders, $count open',
                onPressed: () async {
                  await Navigator.pushNamed(context, '/notifications');
                  if (mounted) setState(_reload);
                },
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search tasks',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
          IconButton(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              icon: const Icon(Icons.history),
              tooltip: 'History'),
          IconButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () => _changeDate(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous day'),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(children: [
                        Text(_dateHeading(_selectedDate),
                            style: Theme.of(context).textTheme.titleLarge),
                        const Text('Tap to choose a date'),
                      ]),
                    ),
                  ),
                ),
                IconButton(
                    onPressed: () => _changeDate(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next day'),
                IconButton(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    tooltip: 'Choose date'),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('All tasks'),
                    icon: Icon(Icons.view_list_outlined)),
                ButtonSegment(
                    value: false,
                    label: Text('Date agenda'),
                    icon: Icon(Icons.today_outlined)),
              ],
              selected: {_showAllTasks},
              onSelectionChanged: (selection) =>
                  setState(() => _showAllTasks = selection.first),
            ),
            const SizedBox(height: 12),
            Text(_showAllTasks ? 'Your tasks' : 'Your agenda',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            FutureBuilder<_AgendaData>(
              future: _agenda,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Could not load tasks: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = _searchController.text.trim().toLowerCase();
                final sourceTasks = _showAllTasks
                    ? snapshot.data!.allTasks
                    : snapshot.data!.tasks;
                final tasks = sourceTasks
                    .where((task) =>
                        task.title.toLowerCase().contains(query) ||
                        task.notes.toLowerCase().contains(query) ||
                        task.groupName.toLowerCase().contains(query))
                    .toList();
                final pendingDates = {
                  for (final task in snapshot.data!.allTasks)
                    task.id: nextPendingOccurrence(
                      task: task,
                      completions: snapshot.data!.completions,
                      occurrences: snapshot.data!.allOccurrences,
                      asOf: DateTime.now(),
                    ),
                };
                final plannedOccurrences =
                    snapshot.data!.plannedOccurrences.where((occurrence) {
                  final task = snapshot.data!.allTasks
                      .where((item) => item.id == occurrence.taskId)
                      .firstOrNull;
                  return query.isEmpty ||
                      (task != null &&
                          '${task.title} ${occurrence.note}'
                              .toLowerCase()
                              .contains(query));
                }).toList();
                if (tasks.isEmpty && plannedOccurrences.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                        child: Text(query.isNotEmpty
                            ? 'No tasks match your search.'
                            : _showAllTasks
                                ? 'No tasks yet. Add a task to get started.'
                                : 'Nothing scheduled for this date.')),
                  );
                }
                if (_showAllTasks) {
                  return _groupedTasks(tasks, snapshot.data!.completions,
                      pendingDates, snapshot.data!.allOccurrences);
                }
                return Column(children: [
                  ...tasks.map((task) => _taskTile(
                        task,
                        snapshot.data!.completions,
                        showCompletion: true,
                        occurrences: snapshot.data!.allOccurrences,
                      )),
                  ...plannedOccurrences.map((occurrence) =>
                      _plannedVisitTile(occurrence, snapshot.data!.allTasks)),
                ]);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      TaskEditorPage(repository: widget.repository)));
          if (changed == true && mounted) setState(_reload);
        },
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
    );
  }

  Widget _groupedTasks(List<Task> tasks, List<Completion> completions,
      Map<String, DateTime?> pendingDates, List<TaskOccurrence> occurrences) {
    final groups = <String, List<Task>>{};
    for (final task in tasks) {
      final group =
          task.groupName.trim().isEmpty ? 'Ungrouped' : task.groupName.trim();
      groups.putIfAbsent(group, () => []).add(task);
    }
    final orderedGroups = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final group in orderedGroups) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(children: [
            Expanded(
                child: Text(group,
                    style: Theme.of(context).textTheme.titleMedium)),
            Text('${groups[group]!.length}',
                style: Theme.of(context).textTheme.labelMedium),
          ]),
        ),
        ...groups[group]!.map((task) => _taskTile(task, completions,
            showCompletion: pendingDates[task.id] != null,
            pendingAt: pendingDates[task.id],
            occurrences: occurrences)),
      ],
    ]);
  }

  Widget _taskTile(Task task, List<Completion> completions,
      {required bool showCompletion,
      DateTime? pendingAt,
      List<TaskOccurrence> occurrences = const []}) {
    final selectedOccurrence = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, task.createdAt.hour, task.createdAt.minute);
    final occurrence = pendingAt ?? selectedOccurrence;
    final completion = completions
        .where((item) =>
            item.taskId == task.id && _sameDay(item.completedAt, occurrence))
        .firstOrNull;
    final isDone = completion?.isDone == true;
    final isOverdue = showCompletion &&
        occurrence.isBefore(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final details = <String>[
      TimeOfDay.fromDateTime(task.createdAt).format(context),
      _recurrenceLabel(task),
      if (isOverdue) 'OVERDUE · ${_dateHeading(occurrence)}',
      if (_nextDue(task, occurrences) case final next?)
        'Next · ${_dateHeading(next)}',
      if (task.notes.isNotEmpty) task.notes,
      if (completion?.note.isNotEmpty == true) 'Note: ${completion!.note}',
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          TaskArtwork(task: task, size: 42),
          if (showCompletion)
            IconButton(
              tooltip: isDone ? 'Marked done' : isOverdue ? 'Mark overdue task complete' : 'Mark done',
              onPressed: isDone
                  ? null
                  : () async {
                      final note = await _askNote(true);
                      if (note == null) return;
                      await widget.repository.recordCompletion(task, occurrence, isDone: true, note: note);
                      if (mounted) setState(_reload);
                    },
              icon: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : isOverdue ? Colors.red : null),
            ),
        ]),
        title: Text(task.title,
            style: isOverdue
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null),
        subtitle: Text(details),
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TaskDetailPage(
                      repository: widget.repository, task: task)));
          if (mounted) setState(_reload);
        },
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TaskEditorPage(
                          repository: widget.repository, task: task)));
              if (changed == true && mounted) setState(_reload);
              return;
            }
            if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete task?'),
                  content: Text(
                      '“${task.title}” and its completion history will be permanently removed.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed == true) {
                await widget.repository.deleteTask(task.id);
                if (mounted) setState(_reload);
              }
              return;
            }
            if (value == 'toggle-reminders') {
              await widget.repository
                  .setTaskRemindersMuted(task.id, !task.remindersMuted);
              if (mounted) setState(_reload);
              return;
            }
            final note = await _askNote(false);
            if (note == null) return;
            await widget.repository
                .recordCompletion(task, occurrence, isDone: false, note: note);
            if (mounted) setState(_reload);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit task')),
            PopupMenuItem(
                value: 'toggle-reminders',
                child: Text(task.remindersMuted
                    ? 'Unmute reminders'
                    : 'Mute reminders')),
            const PopupMenuItem(
                value: 'not-done', child: Text('Mark not done')),
            const PopupMenuItem(value: 'delete', child: Text('Delete task')),
          ],
        ),
      ),
    );
  }

  Widget _plannedVisitTile(TaskOccurrence occurrence, List<Task> tasks) {
    final task =
        tasks.where((item) => item.id == occurrence.taskId).firstOrNull;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
        title: Text(task?.title ?? 'Scheduled activity'),
        subtitle: Text(
            '${TimeOfDay.fromDateTime(occurrence.scheduledAt).format(context)} · Planned activity${occurrence.note.isEmpty ? '' : ' · ${occurrence.note}'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          if (task == null) return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TaskDetailPage(
                      repository: widget.repository, task: task)));
          if (mounted) setState(_reload);
        },
      ),
    );
  }

  Future<void> _changeDate(int days) async {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _reload();
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (selected != null) {
      setState(() {
        _selectedDate = DateTime(selected.year, selected.month, selected.day);
        _reload();
      });
    }
  }

  Future<String?> _askNote(bool done) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(done ? 'Mark done' : 'Mark not done'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Note (optional)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _dateHeading(DateTime date) =>
      '${_weekday(date.weekday)}, ${date.month}/${date.day}/${date.year}';

  String _weekday(int day) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][day - 1];

  String _recurrenceLabel(Task task) {
    final rule = task.recurrence;
    if (rule.frequency.name == 'once') return 'One time';
    final unit = switch (rule.frequency.name) {
      'daily' => 'day',
      'weekly' => 'week',
      'monthly' => 'month',
      'yearly' => 'year',
      _ => 'interval',
    };
    final cadence =
        rule.interval == 1 ? 'Every $unit' : 'Every ${rule.interval} ${unit}s';
    final anchor = rule.repeatAfterCompletion ? ' after completion' : '';
    return rule.frequency.name == 'weekly' && rule.weekdays.isNotEmpty
        ? '$cadence · ${rule.weekdays.map((day) => _weekday(day).substring(0, 3)).join(', ')}$anchor'
        : '$cadence$anchor';
  }

  DateTime? _nextDue(Task task, List<TaskOccurrence> occurrences) {
    final completions = occurrences
        .where((item) =>
            item.taskId == task.id &&
            item.status == OccurrenceStatus.completed &&
            item.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final anchor =
        task.recurrence.repeatAfterCompletion && completions.isNotEmpty
            ? completions.first.completedAt!
            : task.createdAt;
    final start = DateTime.now();
    var date = DateTime(start.year, start.month, start.day);
    final lastDate = DateTime(date.year + 10, date.month, date.day);
    while (!date.isAfter(lastDate)) {
      if (task.recurrence.isDueOn(date, anchor)) return date;
      date = date.add(const Duration(days: 1));
    }
    return null;
  }

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _AgendaData {
  const _AgendaData(this.tasks, this.completions, this.plannedOccurrences,
      this.allTasks, this.allOccurrences);

  final List<Task> tasks;
  final List<Completion> completions;
  final List<TaskOccurrence> plannedOccurrences;
  final List<Task> allTasks;
  final List<TaskOccurrence> allOccurrences;
}

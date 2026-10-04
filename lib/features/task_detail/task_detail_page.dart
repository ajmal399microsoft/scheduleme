import 'package:flutter/material.dart';

import '../../models/recurrence_rule.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../repositories/task_repository.dart';
import '../task_editor/task_editor_page.dart';
import '../tasks/task_artwork.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage(
      {required this.repository, required this.task, super.key});

  final TaskRepository repository;
  final Task task;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late Task _task;
  late Future<List<TaskOccurrence>> _occurrences;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _reload();
  }

  void _reload() => _occurrences = widget.repository.occurrences(_task.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_task.title),
        actions: [
          IconButton(
              tooltip: 'Edit schedule',
              onPressed: _editTask,
              icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: FutureBuilder<List<TaskOccurrence>>(
        future: _occurrences,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child:
                    Text('Could not load activity history: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final occurrences = snapshot.data!;
          final completed = occurrences
              .where((item) => item.status == OccurrenceStatus.completed)
              .toList();
          final totalAmount = completed.fold<int>(
              0, (sum, item) => sum + (item.amountMinorUnits ?? 0));
          final planned = occurrences
              .where((item) => item.status == OccurrenceStatus.planned)
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          final next = planned
              .where((item) => !item.scheduledAt.isBefore(DateTime.now()))
              .firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Center(child: TaskArtwork(task: _task, size: 104)),
              const SizedBox(height: 16),
              if (_task.groupName.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                        avatar: const Icon(Icons.folder_outlined, size: 18),
                        label: Text(_task.groupName)),
                  ),
                ),
              _scheduleCard(next, occurrences),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _metric('Completed', '${completed.length}',
                        Icons.check_circle_outline)),
                const SizedBox(width: 12),
                Expanded(
                    child: _metric('Total amount', _money(totalAmount, 'INR'),
                        Icons.payments_outlined)),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: Text('Activity history',
                        style: Theme.of(context).textTheme.titleLarge)),
                TextButton.icon(
                    onPressed: () =>
                        _editOccurrence(status: OccurrenceStatus.completed),
                    icon: const Icon(Icons.add),
                    label: const Text('Log activity')),
              ]),
              const SizedBox(height: 8),
              if (occurrences.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Column(children: [
                    Icon(Icons.event_note_outlined, size: 42),
                    SizedBox(height: 12),
                    Text('No activity recorded yet'),
                    Text(
                        'Plan a future activity or log one that already happened.')
                  ]),
                )
              else
                ...occurrences.map(_occurrenceTile),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editOccurrence(status: OccurrenceStatus.planned),
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Plan activity'),
      ),
    );
  }

  Widget _scheduleCard(TaskOccurrence? next, List<TaskOccurrence> occurrences) {
    final recurrence = _task.recurrence;
    final nextDue = _nextRecurringDate(occurrences);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_repeat_outlined),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Task schedule',
                    style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
                tooltip: 'Edit schedule',
                onPressed: _editTask,
                icon: const Icon(Icons.edit_outlined))
          ]),
          Text(_recurrenceText(recurrence)),
          const SizedBox(height: 4),
          Text(next == null
              ? (nextDue == null
                  ? 'No upcoming activity is scheduled'
                  : 'Next due · ${_dateOnly(nextDue)} at ${TimeOfDay.fromDateTime(_task.createdAt).format(context)}')
              : 'Next individually planned · ${_dateTime(next.scheduledAt)}'),
        ]),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label),
          ]),
        ),
      );

  Widget _occurrenceTile(TaskOccurrence occurrence) {
    final completed = occurrence.status == OccurrenceStatus.completed;
    final planned = occurrence.status == OccurrenceStatus.planned;
    final statusLabel = planned
        ? 'PLANNED'
        : completed
            ? 'COMPLETED'
            : 'MISSED';
    final statusColor = planned
        ? Colors.blue
        : completed
            ? Colors.green
            : Colors.red;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.12),
            child: Icon(
                planned
                    ? Icons.event_outlined
                    : completed
                        ? Icons.check
                        : Icons.remove_circle_outline,
                color: statusColor)),
        title: Text(_dateTime(occurrence.scheduledAt)),
        subtitle: Text([
          statusLabel,
          if (occurrence.completedAt != null &&
              !_sameDateTime(occurrence.completedAt!, occurrence.scheduledAt))
            'Actual · ${_dateTime(occurrence.completedAt!)}',
          if (occurrence.amountMinorUnits != null)
            _money(occurrence.amountMinorUnits!, occurrence.currencyCode),
          if (occurrence.note.isNotEmpty) occurrence.note,
        ].join(' · ')),
        trailing: PopupMenuButton<String>(
          tooltip: 'Activity actions',
          onSelected: (action) async {
            if (action == 'complete') {
              await _editOccurrence(
                  status: OccurrenceStatus.completed, existing: occurrence);
            } else if (action == 'missed') {
              await widget.repository.saveOccurrence(TaskOccurrence(
                id: occurrence.id,
                taskId: occurrence.taskId,
                scheduledAt: occurrence.scheduledAt,
                status: OccurrenceStatus.missed,
                note: occurrence.note,
              ));
              if (mounted) setState(_reload);
            } else if (action == 'edit') {
              await _editOccurrence(
                  status: occurrence.status, existing: occurrence);
            } else if (action == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete activity?'),
                  content: const Text(
                      'This activity record will be permanently removed.'),
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
                await widget.repository.deleteOccurrence(occurrence.id);
                if (mounted) setState(_reload);
              }
            }
          },
          itemBuilder: (_) => [
            if (planned)
              const PopupMenuItem(
                  value: 'complete', child: Text('Log completed activity')),
            if (planned)
              const PopupMenuItem(
                  value: 'missed', child: Text('Mark as missed')),
            const PopupMenuItem(value: 'edit', child: Text('Edit activity')),
            const PopupMenuItem(
                value: 'delete', child: Text('Delete activity')),
          ],
        ),
      ),
    );
  }

  Future<void> _editTask() async {
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                TaskEditorPage(repository: widget.repository, task: _task)));
    if (changed != true || !mounted) {
      return;
    }
    final updated = await widget.repository.taskById(_task.id);
    if (updated != null && mounted) {
      setState(() {
        _task = updated;
        _reload();
      });
    }
  }

  DateTime? _nextRecurringDate(List<TaskOccurrence> occurrences) {
    if (_task.recurrence.frequency == RecurrenceFrequency.once) return null;
    final completions = occurrences
        .where((item) =>
            item.status == OccurrenceStatus.completed &&
            item.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final anchor =
        _task.recurrence.repeatAfterCompletion && completions.isNotEmpty
            ? completions.first.completedAt!
            : _task.createdAt;
    final now = DateTime.now();
    var date = DateTime(now.year, now.month, now.day);
    final limit = DateTime(date.year + 10, date.month, date.day);
    while (!date.isAfter(limit)) {
      if (_task.recurrence.isDueOn(date, anchor)) return date;
      date = date.add(const Duration(days: 1));
    }
    return null;
  }

  Future<void> _editOccurrence(
      {required OccurrenceStatus status, TaskOccurrence? existing}) async {
    final pageContext = context;
    final now = DateTime.now();
    var scheduledAt = existing?.scheduledAt ?? now;
    var completedAt = existing?.completedAt ?? now;
    final amountController = TextEditingController(
        text: existing?.amountMinorUnits == null
            ? ''
            : (existing!.amountMinorUnits! / 100).toStringAsFixed(2));
    final noteController = TextEditingController(text: existing?.note ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<TaskOccurrence>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Text(existing == null
              ? (status == OccurrenceStatus.planned
                  ? 'Plan activity'
                  : 'Log activity')
              : status == OccurrenceStatus.completed
                  ? 'Record completed activity'
                  : 'Edit activity'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _dateTimePicker(pageContext, 'Scheduled for', scheduledAt,
                      (value) => dialogSetState(() => scheduledAt = value)),
                  if (status == OccurrenceStatus.completed)
                    _dateTimePicker(
                        pageContext,
                        'Activity completed',
                        completedAt,
                        (value) => dialogSetState(() => completedAt = value)),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Amount (optional)',
                        prefixText:
                            _currencySymbol(existing?.currencyCode ?? 'INR'),
                        hintText: '0.00'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final amount = double.tryParse(value.trim());
                      if (amount == null || amount < 0) {
                        return 'Enter a valid non-negative amount';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Add useful details about this activity')),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final amount = double.tryParse(amountController.text.trim());
                Navigator.pop(
                    dialogContext,
                    TaskOccurrence(
                      id: existing?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      taskId: _task.id,
                      scheduledAt: scheduledAt,
                      status: status,
                      completedAt: status == OccurrenceStatus.completed
                          ? completedAt
                          : null,
                      amountMinorUnits:
                          amount == null ? null : (amount * 100).round(),
                      currencyCode: existing?.currencyCode ?? 'INR',
                      note: noteController.text.trim(),
                    ));
              },
              child: Text(status == OccurrenceStatus.planned
                  ? 'Save plan'
                  : 'Save activity'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (result != null) {
      await widget.repository.saveOccurrence(result);
      if (mounted) setState(_reload);
    }
  }

  Widget _dateTimePicker(BuildContext context, String label, DateTime value,
          ValueChanged<DateTime> onChanged) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(label),
        subtitle: Text(_dateTime(value)),
        onTap: () async {
          final date = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (date == null || !context.mounted) return;
          final time = await showTimePicker(
              context: context, initialTime: TimeOfDay.fromDateTime(value));
          if (time != null && context.mounted) {
            onChanged(DateTime(
                date.year, date.month, date.day, time.hour, time.minute));
          }
        },
      );

  String _recurrenceText(RecurrenceRule rule) {
    if (rule.frequency == RecurrenceFrequency.once) {
      return 'One-time schedule · ${_dateTime(_task.createdAt)}';
    }
    final unit = switch (rule.frequency) {
      RecurrenceFrequency.daily => 'day',
      RecurrenceFrequency.weekly => 'week',
      RecurrenceFrequency.monthly => 'month',
      RecurrenceFrequency.yearly => 'year',
      RecurrenceFrequency.once => 'activity',
    };
    final cadence =
        rule.interval == 1 ? 'Every $unit' : 'Every ${rule.interval} ${unit}s';
    final days =
        rule.frequency == RecurrenceFrequency.weekly && rule.weekdays.isNotEmpty
            ? ' · ${rule.weekdays.map(_weekdayShort).join(', ')}'
            : '';
    final end =
        rule.endDate == null ? '' : ' · Until ${_dateOnly(rule.endDate!)}';
    final anchor = rule.repeatAfterCompletion ? ' after each completion' : '';
    return '$cadence$days at ${TimeOfDay.fromDateTime(_task.createdAt).format(context)}$anchor$end';
  }

  String _weekdayShort(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  String _dateTime(DateTime value) =>
      '${_dateOnly(value)} · ${TimeOfDay.fromDateTime(value).format(context)}';
  String _dateOnly(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} ${value.year}';
  String _month(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][month - 1];
  String _currencySymbol(String code) => code == 'INR' ? '₹ ' : '$code ';
  String _money(int minorUnits, String currencyCode) =>
      '${_currencySymbol(currencyCode)}${(minorUnits / 100).toStringAsFixed(2)}';
  bool _sameDateTime(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day &&
      left.hour == right.hour &&
      left.minute == right.minute;
}

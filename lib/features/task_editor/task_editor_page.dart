import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/files/attachment_store.dart';
import '../../models/recurrence_rule.dart';
import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../tasks/task_artwork.dart';

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({required this.repository, this.task, super.key});

  final TaskRepository repository;
  final Task? task;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _groupController = TextEditingController();
  final _groupFocusNode = FocusNode();
  final _notesController = TextEditingController();
  final _attachmentStore = AttachmentStore();
  List<String> _existingGroups = const [];
  XFile? _pickedImage;
  String _iconKey = 'task';
  bool _removeAttachment = false;
  late DateTime _startAt;
  late RecurrenceFrequency _frequency;
  late int _interval;
  late List<int> _weekdays;
  late bool _repeatAfterCompletion;
  DateTime? _endDate;
  bool _hasEndDate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _startAt = task?.createdAt ?? DateTime.now();
    _frequency = task?.recurrence.frequency ?? RecurrenceFrequency.once;
    _interval = task?.recurrence.interval ?? 1;
    _weekdays = List<int>.from(task?.recurrence.weekdays ?? <int>[]);
    _repeatAfterCompletion = task?.recurrence.repeatAfterCompletion ?? false;
    _endDate = task?.recurrence.endDate;
    _hasEndDate = _endDate != null;
    _titleController.text = task?.title ?? '';
    _groupController.text = task?.groupName ?? '';
    _notesController.text = task?.notes ?? '';
    _iconKey = task?.iconKey ?? 'task';
    widget.repository.existingGroups().then((groups) {
      if (mounted) setState(() => _existingGroups = groups);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    _groupFocusNode.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.task == null ? 'New task' : 'Edit task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Task name', hintText: 'e.g. Change the sheets'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Give this task a name'
                  : null,
            ),
            const SizedBox(height: 12),
            RawAutocomplete<String>(
              textEditingController: _groupController,
              focusNode: _groupFocusNode,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                return _existingGroups.where((group) =>
                    query.isEmpty || group.toLowerCase().contains(query));
              },
              displayStringForOption: (group) => group,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                    labelText: 'Group (optional)',
                    hintText: 'e.g. Personal care, Home, Car123'),
                textCapitalization: TextCapitalization.sentences,
                onFieldSubmitted: (_) => onFieldSubmitted(),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final group = options.elementAt(index);
                        return ListTile(
                            title: Text(group), onTap: () => onSelected(group));
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Task icon', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: taskIconChoices.entries
                  .map((entry) => ChoiceChip(
                        avatar: Icon(entry.value, size: 18),
                        label: Text(_iconLabel(entry.key)),
                        selected: _iconKey == entry.key,
                        onSelected: (_) => setState(() => _iconKey = entry.key),
                      ))
                  .toList(),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 20),
              Text('Task photo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_pickedImage != null ||
                          (widget.task?.attachmentPath != null &&
                              !_removeAttachment)
                      ? 'Change photo'
                      : 'Add photo'),
                ),
                if (_pickedImage != null ||
                    (widget.task?.attachmentPath != null && !_removeAttachment))
                  IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () => setState(() {
                            _pickedImage = null;
                            _removeAttachment = true;
                          }),
                      icon: const Icon(Icons.delete_outline)),
              ]),
              if (_pickedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_pickedImage!.path),
                      height: 144, width: 200, fit: BoxFit.cover),
                )
              else if (widget.task?.attachmentPath != null &&
                  !_removeAttachment)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(widget.task!.attachmentPath!),
                      height: 144,
                      width: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                          height: 80,
                          child: Center(
                              child: Text(
                                  'Photo is unavailable on this device.')))),
                ),
            ],
            const SizedBox(height: 16),
            Text('Schedule', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _frequency,
              items: const [
                DropdownMenuItem(
                    value: RecurrenceFrequency.once,
                    child: Text('Does not repeat')),
                DropdownMenuItem(
                    value: RecurrenceFrequency.daily, child: Text('Every day')),
                DropdownMenuItem(
                    value: RecurrenceFrequency.weekly,
                    child: Text('Every week')),
                DropdownMenuItem(
                    value: RecurrenceFrequency.monthly,
                    child: Text('Every month')),
                DropdownMenuItem(
                    value: RecurrenceFrequency.yearly,
                    child: Text('Every year')),
              ].toList(),
              onChanged: (value) => setState(() => _frequency = value!),
            ),
            if (_frequency != RecurrenceFrequency.once) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _interval,
                decoration: const InputDecoration(labelText: 'Repeat every'),
                items: List.generate(30, (index) => index + 1)
                    .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value ${_unitLabel(value)}')))
                    .toList(),
                onChanged: (value) => setState(() => _interval = value!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat after completion'),
                subtitle: const Text(
                    'Count the next interval from when you finish this task'),
                value: _repeatAfterCompletion,
                onChanged: (value) => setState(() {
                  _repeatAfterCompletion = value;
                  if (value) _weekdays.clear();
                }),
              ),
            ],
            if (_frequency == RecurrenceFrequency.weekly &&
                !_repeatAfterCompletion) ...[
              const SizedBox(height: 16),
              Text('Repeat on', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 6,
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  return FilterChip(
                    label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][index]),
                    selected: _weekdays.contains(weekday),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weekdays.add(weekday);
                      } else {
                        _weekdays.remove(weekday);
                      }
                    }),
                  );
                }),
              ),
            ],
            if (_frequency == RecurrenceFrequency.monthly) ...[
              const SizedBox(height: 8),
              Text('On day ${_startAt.day} of the month',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Start date'),
              subtitle: Text(_dateLabel(_startAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickStartDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Time'),
              subtitle: Text(TimeOfDay.fromDateTime(_startAt).format(context)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _pickStartTime,
            ),
            if (_frequency != RecurrenceFrequency.once) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set an end date'),
                value: _hasEndDate,
                onChanged: (value) => setState(() {
                  _hasEndDate = value;
                  _endDate ??= _startAt.add(const Duration(days: 30));
                }),
              ),
              if (_hasEndDate)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat until'),
                  subtitle: Text(_dateLabel(_endDate!)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickEndDate,
                ),
            ],
            const SizedBox(height: 16),
            TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                    labelText: 'Notes', alignLabelWithHint: true),
                maxLines: 4),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Save task'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _startAt,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    setState(() => _startAt = DateTime(
        date.year, date.month, date.day, _startAt.hour, _startAt.minute));
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (image != null && mounted) {
      setState(() {
        _pickedImage = image;
        _removeAttachment = false;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_startAt));
    if (time != null) {
      setState(() => _startAt = DateTime(
          _startAt.year, _startAt.month, _startAt.day, time.hour, time.minute));
    }
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
        context: context,
        initialDate: _endDate!,
        firstDate: DateTime(_startAt.year, _startAt.month, _startAt.day),
        lastDate: DateTime(2100));
    if (selected != null) setState(() => _endDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frequency == RecurrenceFrequency.weekly &&
        !_repeatAfterCompletion &&
        _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose at least one weekday')));
      return;
    }
    if (_hasEndDate &&
        _endDate!
            .isBefore(DateTime(_startAt.year, _startAt.month, _startAt.day))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The end date must be on or after the start date')));
      return;
    }
    setState(() => _saving = true);
    final taskId =
        widget.task?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final oldAttachmentPath = widget.task?.attachmentPath;
    String? newAttachmentPath;
    try {
      var attachmentPath = _removeAttachment ? null : oldAttachmentPath;
      if (_pickedImage != null) {
        newAttachmentPath = await _attachmentStore.save(File(_pickedImage!.path), taskId);
        attachmentPath = newAttachmentPath;
      }
      final task = Task(
        id: taskId,
        title: _titleController.text.trim(),
        groupName: _groupController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: _startAt,
        recurrence: RecurrenceRule(
          frequency: _frequency,
          interval: _interval,
          weekdays: List<int>.from(_weekdays),
          endDate: _hasEndDate ? _endDate : null,
          repeatAfterCompletion: _repeatAfterCompletion,
        ),
        attachmentPath: attachmentPath,
        isArchived: widget.task?.isArchived ?? false,
        remindersMuted: widget.task?.remindersMuted ?? false,
        iconKey: _iconKey,
      );
      await widget.repository.save(task);
      if (oldAttachmentPath != null && oldAttachmentPath != attachmentPath) {
        try {
          await _attachmentStore.delete(oldAttachmentPath);
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (newAttachmentPath != null && newAttachmentPath != oldAttachmentPath) {
        try {
          await _attachmentStore.delete(newAttachmentPath);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save this task. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _iconLabel(String key) => '${key[0].toUpperCase()}${key.substring(1)}';

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _unitLabel(int count) {
    final unit = switch (_frequency) {
      RecurrenceFrequency.daily => 'day',
      RecurrenceFrequency.weekly => 'week',
      RecurrenceFrequency.monthly => 'month',
      RecurrenceFrequency.yearly => 'year',
      RecurrenceFrequency.once => '',
    };
    return count == 1 ? unit : '${unit}s';
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/backup/google_drive_backup_coordinator.dart';
import '../../core/notifications/task_reminder_service.dart';
import '../../repositories/task_repository.dart';
import 'google_sign_in_button.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {required this.backupCoordinator,
      required this.repository,
      required this.reminderService,
      super.key});

  final GoogleDriveBackupCoordinator backupCoordinator;
  final TaskRepository repository;
  final TaskReminderService reminderService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  GoogleDriveBackupCoordinator get _backup => widget.backupCoordinator;
  bool _reminderBusy = false;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    _backup.addListener(_onBackupChanged);
    _backup.initialize();
  }

  @override
  void dispose() {
    _backup.removeListener(_onBackupChanged);
    super.dispose();
  }

  void _onBackupChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    try {
      await _backup.signIn();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _restore() async {
    try {
      final preview = await _backup.loadRestorePreview();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore backup?'),
          content: Text(
              'Backup from ${_formatDateTime(preview.document.createdAt.toLocal())}\n\n'
              '${preview.document.tasks.length} tasks\n${preview.document.completions.length + preview.document.occurrences.length} activity records\n\n'
              'This replaces all task data currently on this device. The downloaded archive has been validated before any local data changes.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Replace local data')),
          ],
        ),
      );
      if (confirmed == true) await _backup.restore(preview.document);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _setAutomaticBackup(bool enabled) async {
    try {
      await _backup.setAutomaticBackupEnabled(enabled);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _disconnect() async {
    try {
      await _backup.disconnect();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _setDailyReminders(bool enabled) async {
    setState(() {
      _reminderBusy = true;
      _reminderError = null;
    });
    try {
      final updated = await widget.reminderService.setEnabled(enabled);
      if (!updated) {
        _reminderError = enabled
            ? 'Allow notifications in system settings to enable daily reminders.'
            : null;
      } else if (enabled) {
        await widget.reminderService.refresh(widget.repository);
      }
    } catch (_) {
      _reminderError = 'Could not update reminders. Please try again.';
      if (widget.reminderService.enabled) {
        await widget.reminderService.setEnabled(false);
      }
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = _backup.account;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Account and backup', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
              'Backups are optional. Tasks remain available locally without signing in.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _backup.busy && account == null
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator()))
                  : account == null
                      ? _connectPanel()
                      : _accountPanel(account.email),
            ),
          ),
          if (_backup.busy)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
          if (_backup.errorMessage != null)
            _message(_backup.errorMessage!, isError: true),
          if (_backup.successMessage != null)
            _message(_backup.successMessage!, isError: false),
          const SizedBox(height: 24),
          Text('Privacy and timing', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('App-private Google Drive storage'),
            subtitle: Text(
                'ScheduleMe uses Drive’s hidden appDataFolder and requests only the drive.appdata permission. The backup is not shown as a regular Drive file. Google sign-in does not share your password with the app. Backup contents use Google Drive transport and storage protections, but are not additionally end-to-end encrypted by ScheduleMe.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_outlined),
            title: Text('Automatic backup timing'),
            subtitle: Text(
                'When enabled, ScheduleMe checks for a backup at app startup, at most once per 24 hours while online. Android and iOS may delay background work and cannot guarantee a specific time.'),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Daily reminders'),
            subtitle: Text(widget.reminderService.available
                ? 'Repeats every morning at 8:00 until tasks are completed or muted.'
                : 'Available on Android and iOS.'),
            value: widget.reminderService.enabled &&
                widget.reminderService.available,
            onChanged: _reminderBusy || !widget.reminderService.available
                ? null
                : _setDailyReminders,
          ),
          if (_reminderBusy) const LinearProgressIndicator(),
          if (_reminderError != null) _message(_reminderError!, isError: true),
          SwitchListTile(
              title: const Text('Use dark appearance'),
              value: false,
              onChanged: (_) {}),
          const AboutListTile(
              applicationName: 'ScheduleMe', applicationVersion: '0.1.0'),
        ],
      ),
    );
  }

  Widget _connectPanel() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.cloud_outlined),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Connect Google to back up and restore your tasks on another device.'))
        ]),
        if (!_backup.configured) ...[
          const SizedBox(height: 14),
          const Text('Google OAuth is not configured for this build.'),
          const SizedBox(height: 6),
          const SelectableText(configurationInstructions),
        ] else ...[
          const SizedBox(height: 14),
          if (kIsWeb)
            Align(
                alignment: Alignment.centerLeft,
                child: buildGoogleSignInButton(onPressed: _connect))
          else
            OutlinedButton.icon(
                onPressed: _backup.busy ? null : _connect,
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google')),
        ],
      ]);

  Widget _accountPanel(String email) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(child: Icon(Icons.account_circle_outlined)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Connected Google account'),
                Text(email)
              ])),
          IconButton(
              tooltip: 'Disconnect Google',
              onPressed: _backup.busy ? null : _disconnect,
              icon: const Icon(Icons.logout)),
        ]),
        if (_backup.driveAuthorized && _backup.latestBackup != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Latest Drive backup'),
            subtitle: Text(_backup.latestBackup!.modifiedAt == null
                ? 'Available'
                : _formatDateTime(_backup.latestBackup!.modifiedAt!)),
          )
        else if (_backup.lastBackupAt != null)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_done_outlined),
              title: const Text('Last backup'),
              subtitle: Text(_formatDateTime(_backup.lastBackupAt!))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: _backup.busy ? null : _backup.backupNow,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Back up now')),
          OutlinedButton.icon(
              onPressed: _backup.busy ? null : _restore,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Restore latest')),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatic daily backup'),
          subtitle: const Text(
              'When online, checks for a backup at app startup, at most once every 24 hours.'),
          value: _backup.automaticBackupEnabled,
          onChanged: _backup.busy ? null : _setAutomaticBackup,
        ),
      ]);

  Widget _message(String message, {required bool isError}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Material(
          color: isError
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ]),
          ),
        ),
      );

  String _formatDateTime(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(value).format(context)}';
}

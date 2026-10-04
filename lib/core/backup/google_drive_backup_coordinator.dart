import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'backup_document.dart';
import 'drive_backup_service.dart';

const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
const automaticBackupPreferenceKey = 'drive_auto_backup_enabled';
const lastBackupPreferenceKey = 'drive_last_backup_at';

class GoogleDriveBackupCoordinator extends ChangeNotifier {
  GoogleDriveBackupCoordinator(this._database);

  final AppDatabase _database;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authenticationSubscription;
  GoogleSignInAccount? _account;
  DriveBackupInfo? _latestBackup;
  DateTime? _lastBackupAt;
  Future<void>? _initialization;
  bool _configured = false;
  bool _driveAuthorized = false;
  bool _busy = false;
  bool _automaticBackupRunning = false;
  String? _errorMessage;
  String? _successMessage;
  int _restoreRevision = 0;

  GoogleSignInAccount? get account => _account;
  DriveBackupInfo? get latestBackup => _latestBackup;
  DateTime? get lastBackupAt => _lastBackupAt;
  bool get configured => _configured;
  bool get driveAuthorized => _driveAuthorized;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get automaticBackupEnabled => _automaticBackupEnabled;
  int get restoreRevision => _restoreRevision;
  bool _automaticBackupEnabled = false;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _automaticBackupEnabled = prefs.getBool(automaticBackupPreferenceKey) ?? false;
      _configured = kIsWeb ? googleWebClientId.isNotEmpty : googleServerClientId.isNotEmpty;
      if (!_configured) {
        notifyListeners();
        return;
      }
      await _googleSignIn.initialize(
        clientId: kIsWeb ? googleWebClientId : null,
        serverClientId: kIsWeb ? null : googleServerClientId,
      );
      _authenticationSubscription = _googleSignIn.authenticationEvents.listen(_handleAuthenticationEvent, onError: (Object error) {
        _errorMessage = _friendlyError(error);
        notifyListeners();
      });
      final accountFuture = _googleSignIn.attemptLightweightAuthentication();
      if (accountFuture != null) {
        final restoredAccount = await accountFuture;
        if (restoredAccount != null) {
          _account = restoredAccount;
          await _loadAccountBackupTime(restoredAccount);
          await _tryAutomaticBackup();
        }
      }
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        _account = user;
        await _loadAccountBackupTime(user);
        _errorMessage = null;
        notifyListeners();
        await _tryAutomaticBackup();
      case GoogleSignInAuthenticationEventSignOut():
        _account = null;
        _latestBackup = null;
        _lastBackupAt = null;
        _driveAuthorized = false;
        notifyListeners();
    }
  }

  Future<void> signIn() async {
    await initialize();
    if (!_configured) throw const DriveBackupException(configurationInstructions);
    if (!_googleSignIn.supportsAuthenticate()) return;
    _setBusy(true);
    try {
      _account = await _googleSignIn.authenticate();
      await _loadAccountBackupTime(_account!);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> disconnect() async {
    _setBusy(true);
    try {
      await _googleSignIn.signOut();
      _account = null;
      _latestBackup = null;
      _driveAuthorized = false;
      _successMessage = 'Google account disconnected. Existing Drive backups are not deleted.';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> setAutomaticBackupEnabled(bool enabled) async {
    await initialize();
    if (enabled && _account == null) throw const DriveBackupException('Connect a Google account before enabling automatic backups.');
    _setBusy(true);
    try {
      if (enabled) {
        final authorization = await _authorizeDrive(interactive: true);
        if (authorization == null) throw const DriveBackupException('Google Drive authorization was not granted.');
      }
      _automaticBackupEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(automaticBackupPreferenceKey, enabled);
      _successMessage = enabled ? 'Automatic backup is enabled.' : 'Automatic backup is disabled.';
      if (enabled) await _runBackup();
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> backupNow() async {
    await initialize();
    if (_account == null) throw const DriveBackupException('Connect a Google account before backing up.');
    _setBusy(true);
    try {
      await _runBackup(interactiveAuthorization: true);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<BackupRestorePreview> loadRestorePreview() async {
    await initialize();
    if (_account == null) throw const DriveBackupException('Connect the Google account that contains your backup first.');
    _setBusy(true);
    try {
      final authorization = await _authorizeDrive(interactive: true);
      if (authorization == null) throw const DriveBackupException('Google Drive authorization was not granted.');
      final drive = _drive(authorization.accessToken);
      try {
        final latest = await drive.findLatest();
        if (latest == null) throw const DriveBackupException('No ScheduleMe backup was found in this Google account.');
        final document = BackupDocument.decode(await drive.download(latest));
        _latestBackup = latest;
        return BackupRestorePreview(document: document, backup: latest);
      } finally {
        drive.close();
      }
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> restore(BackupDocument document) async {
    _setBusy(true);
    try {
      document.validate();
      await document.restore(_database.database);
      _restoreRevision++;
      _successMessage = 'Restore completed. Your local task data has been replaced.';
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _runBackup({bool interactiveAuthorization = false}) async {
    final authorization = await _authorizeDrive(interactive: interactiveAuthorization);
    if (authorization == null) throw const DriveBackupException('Google Drive authorization is required to create a backup.');
    final document = await _database.readSnapshot(BackupDocument.capture);
    document.validate();
    final drive = _drive(authorization.accessToken);
    try {
      final latest = await drive.findLatest();
      await drive.uploadLatest(document.encode(), existing: latest);
      _latestBackup = await drive.findLatest();
    } finally {
      drive.close();
    }
    _lastBackupAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, _lastBackupAt!.toUtc().toIso8601String());
    _successMessage = 'Backup completed: ${document.tasks.length} tasks and their activity history.';
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _tryAutomaticBackup() async {
    if (!_automaticBackupEnabled || _account == null || _automaticBackupRunning) return;
    final last = _lastBackupAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 24)) return;
    _automaticBackupRunning = true;
    try {
      final authorization = await _authorizeDrive(interactive: false);
      if (authorization == null) return;
      await _runBackupWithAuthorization(authorization);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      notifyListeners();
    } finally {
      _automaticBackupRunning = false;
    }
  }

  Future<void> _runBackupWithAuthorization(GoogleSignInClientAuthorization authorization) async {
    final document = await _database.readSnapshot(BackupDocument.capture);
    document.validate();
    final drive = _drive(authorization.accessToken);
    try {
      final latest = await drive.findLatest();
      await drive.uploadLatest(document.encode(), existing: latest);
      _latestBackup = await drive.findLatest();
    } finally {
      drive.close();
    }
    _lastBackupAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, _lastBackupAt!.toUtc().toIso8601String());
    _successMessage = 'Automatic backup completed.';
    notifyListeners();
  }

  Future<GoogleSignInClientAuthorization?> _authorizeDrive({required bool interactive}) async {
    final account = _account;
    if (account == null) throw const DriveBackupException('Connect a Google account before using Drive backups.');
    final authorization = await account.authorizationClient.authorizationForScopes([driveAppDataScope]);
    if (authorization != null) {
      _driveAuthorized = true;
      return authorization;
    }
    if (!interactive) return null;
    final granted = await account.authorizationClient.authorizeScopes([driveAppDataScope]);
    _driveAuthorized = true;
    return granted;
  }

  String get _lastBackupKey => '$lastBackupPreferenceKey.${Uri.encodeComponent(_account?.email ?? 'unknown')}';

  Future<void> _loadAccountBackupTime(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$lastBackupPreferenceKey.${Uri.encodeComponent(account.email)}');
    _lastBackupAt = stored == null ? null : DateTime.tryParse(stored)?.toLocal();
  }

  DriveBackupService _drive(String accessToken) => DriveBackupService(_BearerHttpClient(accessToken));

  void _setBusy(bool value) {
    _busy = value;
    if (value) {
      _errorMessage = null;
      _successMessage = null;
    }
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is DriveBackupException) return error.message;
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) return 'Google sign-in was cancelled.';
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) return 'Google OAuth is not configured correctly. Verify client IDs, Android package ID, and signing SHA-1.';
    }
    return 'Backup operation failed. Check your connection and Google Drive authorization, then try again.';
  }

  @override
  void dispose() {
    _authenticationSubscription?.cancel();
    super.dispose();
  }
}

class BackupRestorePreview {
  const BackupRestorePreview({required this.document, required this.backup});

  final BackupDocument document;
  final DriveBackupInfo backup;
}

class _BearerHttpClient extends http.BaseClient {
  _BearerHttpClient(this._accessToken);

  final String _accessToken;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

const configurationInstructions = 'Google backup needs an OAuth client ID. Android requires a web client ID plus an Android OAuth client registered with the app package name and signing SHA-1. See README.md, then pass --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com. Web also requires GOOGLE_WEB_CLIENT_ID and an authorized JavaScript origin.';

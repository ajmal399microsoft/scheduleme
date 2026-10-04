import 'dart:convert';

import 'package:http/http.dart' as http;

class DriveBackupService {
  DriveBackupService(this._client);

  static const fileName = 'scheduleme-backup-v1.json';
  static final _collectionUri = Uri.https('www.googleapis.com', '/drive/v3/files');
  static final _uploadCollectionUri = Uri.https('www.googleapis.com', '/upload/drive/v3/files');

  final http.Client _client;

  Future<DriveBackupInfo?> findLatest() async {
    final uri = _collectionUri.replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "name = '$fileName' and trashed = false",
      'orderBy': 'modifiedTime desc',
      'pageSize': '1',
      'fields': 'files(id,name,modifiedTime,size)',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    _ensureSuccess(response, 'Check for a backup');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final files = payload['files'] as List<dynamic>? ?? const [];
    if (files.isEmpty) return null;
    final file = files.first as Map<String, dynamic>;
    return DriveBackupInfo(
      id: file['id'] as String,
      modifiedAt: DateTime.tryParse(file['modifiedTime'] as String? ?? '')?.toLocal(),
      sizeBytes: int.tryParse(file['size']?.toString() ?? ''),
    );
  }

  Future<void> uploadLatest(String content, {DriveBackupInfo? existing}) async {
    final bytes = utf8.encode(content);
    if (existing == null) {
      final metadata = jsonEncode({'name': fileName, 'mimeType': 'application/json', 'parents': ['appDataFolder']});
      final boundary = 'scheduleme_${DateTime.now().microsecondsSinceEpoch}';
      final body = <int>[
        ...utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'),
        ...utf8.encode('--$boundary\r\nContent-Type: application/json\r\n\r\n'),
        ...bytes,
        ...utf8.encode('\r\n--$boundary--'),
      ];
      final response = await _client.post(
        _uploadCollectionUri.replace(queryParameters: {'uploadType': 'multipart', 'fields': 'id'}),
        headers: {'Content-Type': 'multipart/related; boundary=$boundary'},
        body: body,
      ).timeout(const Duration(seconds: 60));
      _ensureSuccess(response, 'Create backup');
      return;
    }

    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files/${existing.id}', {'uploadType': 'media'});
    final response = await _client.patch(uri, headers: {'Content-Type': 'application/json'}, body: bytes).timeout(const Duration(seconds: 60));
    _ensureSuccess(response, 'Update backup');
  }

  Future<String> download(DriveBackupInfo backup) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/${backup.id}', {'alt': 'media'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 60));
    _ensureSuccess(response, 'Download backup');
    return utf8.decode(response.bodyBytes);
  }

  void close() => _client.close();

  static void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const DriveBackupException('Google authorization expired or was denied. Reconnect Google Drive and try again.');
    }
    throw DriveBackupException('$action failed (HTTP ${response.statusCode}). Please try again later.');
  }
}

class DriveBackupInfo {
  const DriveBackupInfo({required this.id, this.modifiedAt, this.sizeBytes});

  final String id;
  final DateTime? modifiedAt;
  final int? sizeBytes;
}

class DriveBackupException implements Exception {
  const DriveBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
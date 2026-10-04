import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schedule_me/core/backup/drive_backup_service.dart';

void main() {
  test('lists only the latest ScheduleMe appDataFolder backup', () async {
    late http.Request request;
    final service = DriveBackupService(MockClient((incoming) async {
      request = incoming;
      return http.Response(jsonEncode({
        'files': [
          {'id': 'file-1', 'name': DriveBackupService.fileName, 'modifiedTime': '2026-09-27T10:00:00.000Z', 'size': '42'},
        ],
      }), 200);
    }));
    addTearDown(service.close);

    final backup = await service.findLatest();

    expect(request.url.path, '/drive/v3/files');
    expect(request.url.queryParameters['spaces'], 'appDataFolder');
    expect(request.url.queryParameters['q'], "name = '${DriveBackupService.fileName}' and trashed = false");
    expect(backup?.id, 'file-1');
    expect(backup?.sizeBytes, 42);
  });

  test('creates the single backup inside appDataFolder', () async {
    late http.Request request;
    final service = DriveBackupService(MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', 200);
    }));
    addTearDown(service.close);

    await service.uploadLatest('{"tasks":[]}', existing: null);

    expect(request.method, 'POST');
    expect(request.url.queryParameters['uploadType'], 'multipart');
    expect(request.headers['content-type'], startsWith('multipart/related; boundary='));
    expect(utf8.decode(request.bodyBytes), contains('"parents":["appDataFolder"]'));
    expect(utf8.decode(request.bodyBytes), contains('{"tasks":[]}'));
  });

  test('updates an existing Drive backup instead of creating another file', () async {
    late http.Request request;
    final service = DriveBackupService(MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', 200);
    }));
    addTearDown(service.close);

    await service.uploadLatest('{"tasks":[]}', existing: const DriveBackupInfo(id: 'existing-id'));

    expect(request.method, 'PATCH');
    expect(request.url.path, '/upload/drive/v3/files/existing-id');
    expect(request.url.queryParameters['uploadType'], 'media');
    expect(utf8.decode(request.bodyBytes), '{"tasks":[]}');
  });

  test('downloads backup content and reports expired authorization clearly', () async {
    final service = DriveBackupService(MockClient((request) async => http.Response('{"ok":true}', 200)));
    addTearDown(service.close);
    expect(await service.download(const DriveBackupInfo(id: 'file-id')), '{"ok":true}');

    final expired = DriveBackupService(MockClient((request) async => http.Response('{}', 401)));
    addTearDown(expired.close);
    await expectLater(expired.findLatest(), throwsA(isA<DriveBackupException>().having((error) => error.message, 'message', contains('authorization expired'))));
  });
}
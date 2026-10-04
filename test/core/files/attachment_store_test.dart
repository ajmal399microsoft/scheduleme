import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_me/core/files/attachment_store.dart';

void main() {
  test('copies, encodes, restores, and deletes task photos safely', () async {
    final root = await Directory.systemTemp.createTemp('schedule-me-attachments-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}${Platform.pathSeparator}source.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
    final store = AttachmentStore(documentsDirectoryProvider: () async => root);

    final savedPath = await store.save(source, 'task-1');
    expect(savedPath, isNot(source.path));
    expect(await store.encode(savedPath), 'AQIDBA==');

    final restoredPath = await store.restoreEncoded('AQIDBA==', 'task-1', 'old-photo.jpg');
    expect(restoredPath, isNot(savedPath));
    expect(await File(restoredPath).readAsBytes(), [1, 2, 3, 4]);
    expect(await store.existingPath('${root.path}${Platform.pathSeparator}missing.jpg'), isNull);

    await store.delete(savedPath);
    expect(await File(savedPath).exists(), isFalse);
    expect(await File(restoredPath).exists(), isTrue);
  });
}
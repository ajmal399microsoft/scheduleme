import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AttachmentStore {
  AttachmentStore({Future<Directory> Function()? documentsDirectoryProvider})
      : _documentsDirectoryProvider = documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<String> save(File source, String taskId) async {
    final directory = await _documentsDirectoryProvider();
    final attachments = Directory(path.join(directory.path, 'attachments'));
    await attachments.create(recursive: true);
    final destination = File(path.join(attachments.path,
        '${_safeName(taskId)}-${DateTime.now().microsecondsSinceEpoch}${path.extension(source.path)}'));
    await source.copy(destination.path);
    return destination.path;
  }

  Future<String?> encode(String? attachmentPath) async {
    if (attachmentPath == null) return null;
    final file = File(attachmentPath);
    if (!await file.exists()) return null;
    return base64Encode(await file.readAsBytes());
  }

  Future<String> restoreEncoded(
      String encoded, String taskId, String? originalPath) async {
    final directory = await _documentsDirectoryProvider();
    final attachments = Directory(path.join(directory.path, 'attachments'));
    await attachments.create(recursive: true);
    var extension = path.extension(originalPath ?? '').toLowerCase();
    if (!const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(extension)) {
      extension = '.jpg';
    }
    final destination = File(path.join(attachments.path,
        '${_safeName(taskId)}-restore-${DateTime.now().microsecondsSinceEpoch}$extension'));
    await destination.writeAsBytes(base64Decode(encoded), flush: true);
    return destination.path;
  }

  Future<String?> existingPath(String? attachmentPath) async {
    if (attachmentPath == null) return null;
    return await File(attachmentPath).exists() ? attachmentPath : null;
  }

  Future<void> delete(String? attachmentPath) async {
    if (attachmentPath == null) return;
    final file = File(attachmentPath);
    if (await file.exists()) await file.delete();
  }

  String _safeName(String value) {
    final name =
        path.basename(value).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return name.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : name;
  }
}

import 'dart:io';

import 'package:kronikas_core/story_storage_sync.dart';

/// Persistent synthetic storage for exercising the sync flow without OAuth.
final class StoryStoragePreview implements StoryStorage {
  StoryStoragePreview(this.directory);

  final Directory directory;
  static final _idPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  @override
  String get identity => 'preview:${directory.absolute.path}';

  File _file(String id, int version) {
    if (!_idPattern.hasMatch(id)) throw const FormatException('Invalid ID.');
    return File.fromUri(directory.uri.resolve('$id.$version.json'));
  }

  @override
  Future<Map<String, String>> listVersions() async {
    await directory.create(recursive: true);
    final versions = <String, int>{};
    final pattern = RegExp(r'^([a-zA-Z0-9_-]+)\.([1-9][0-9]*)\.json$');
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final match = pattern.firstMatch(entry.uri.pathSegments.last);
      if (match == null) continue;
      final id = match[1]!;
      final version = int.parse(match[2]!);
      if (version > (versions[id] ?? 0)) versions[id] = version;
    }
    return versions.map((id, version) => MapEntry(id, '$version'));
  }

  @override
  Future<String> read(String id, String version) =>
      _file(id, int.parse(version)).readAsString();

  @override
  Future<String?> write(
    String id,
    String? expectedVersion,
    String snapshot,
  ) async {
    await directory.create(recursive: true);
    final lock = File.fromUri(directory.uri.resolve('writer.lock'))
        .openSync(mode: FileMode.append);
    try {
      lock.lockSync(FileLock.exclusive);
      final version = expectedVersion == null
          ? 1
          : int.parse(expectedVersion) + 1;
      final file = _file(id, version);
      if (file.existsSync()) return null;
      if (version > 1 && !_file(id, version - 1).existsSync()) return null;
      final temp = directory.createTempSync('.pending-');
      try {
        File.fromUri(temp.uri.resolve('story.json'))
            .writeAsStringSync(snapshot, flush: true);
        File.fromUri(temp.uri.resolve('story.json')).renameSync(file.path);
      } finally {
        temp.deleteSync(recursive: true);
      }
      return '$version';
    } finally {
      lock.closeSync();
    }
  }
}

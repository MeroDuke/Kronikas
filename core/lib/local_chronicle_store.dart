import 'dart:io';

import 'kronikas_core.dart';
import 'src/chronicle_json.dart';

/// Stores complete, versioned snapshots in an application-owned directory.
final class LocalChronicleStore {
  LocalChronicleStore(Directory directory) : directory = directory.absolute;

  final Directory directory;
  static final _revisionName = RegExp(r'^revision-([1-9][0-9]*)\.json$');
  static final _activeWrites = <String>{};

  Chronicle open() => _read(_latestRevision());

  /// Applies an operation to the latest snapshot and commits it before returning.
  ///
  /// Use a synchronous callback. A second writer must acquire the file lock
  /// before loading state, so it cannot commit a stale snapshot.
  Chronicle update<T>(T Function(Chronicle) operation) {
    directory.createSync(recursive: true);
    final location = directory.resolveSymbolicLinksSync();
    if (!_activeWrites.add(location)) {
      throw StateError('A local update is already in progress.');
    }
    try {
      final lock = File(_path('writer.lock')).openSync(mode: FileMode.append);
      try {
        lock.lockSync(FileLock.exclusive);
        final previous = _latestRevision();
        final chronicle = _read(previous);
        final result = operation(chronicle);
        if (result is Future) {
          throw ArgumentError('Local updates require a synchronous callback.');
        }
        _commit(chronicle, previous + 1);
        return chronicle;
      } finally {
        lock.closeSync();
      }
    } finally {
      _activeWrites.remove(location);
    }
  }

  void _commit(Chronicle chronicle, int revision) {
    final temporary = directory.createTempSync('.pending-');
    try {
      final staged = File.fromUri(temporary.uri.resolve('snapshot.json'));
      staged.writeAsStringSync(encodeChronicle(chronicle), flush: true);
      staged.renameSync(_path('revision-$revision.json'));
    } finally {
      // A leftover staging directory is harmless and never treated as saved.
      try {
        temporary.deleteSync(recursive: true);
      } on FileSystemException {
        // Cleanup must not change the result of a completed commit.
      }
    }
  }

  Chronicle _read(int revision) => revision == 0
      ? Chronicle()
      : decodeChronicle(
          File(_path('revision-$revision.json')).readAsStringSync(),
        );

  int _latestRevision() {
    if (!directory.existsSync()) return 0;
    var latest = 0;
    for (final entry in directory.listSync(followLinks: false)) {
      if (entry is! File) continue;
      final match = _revisionName.firstMatch(entry.uri.pathSegments.last);
      if (match == null) continue;
      final revision = int.parse(match[1]!);
      if (revision > latest) latest = revision;
    }
    return latest;
  }

  String _path(String name) => directory.uri.resolve(name).toFilePath();
}

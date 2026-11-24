import 'dart:convert';
import 'dart:io';

import 'kronikas_core.dart';
import 'src/chronicle_json.dart';

typedef LocalChronicleRevision = ({
  int revision,
  int dataRevision,
  Chronicle chronicle,
  Map<String, Object?> sync,
});

/// Stores complete, versioned snapshots in an application-owned directory.
final class LocalChronicleStore {
  LocalChronicleStore(Directory directory) : directory = directory.absolute;

  final Directory directory;
  static final _revisionName = RegExp(r'^revision-([1-9][0-9]*)\.json$');
  static final _activeWrites = <String>{};

  Chronicle open() => readRevision().chronicle;

  LocalChronicleRevision readRevision() => _read(_latestRevision());

  /// Applies an operation to the latest snapshot and commits it before returning.
  ///
  /// Use a synchronous callback. A second writer must acquire the file lock
  /// before loading state, so it cannot commit a stale snapshot.
  Chronicle update<T>(T Function(Chronicle) operation) => _withWriteLock(() {
    final previous = readRevision();
    final chronicle = previous.chronicle;
    final result = operation(chronicle);
    if (result is Future) {
      throw ArgumentError('Local updates require a synchronous callback.');
    }
    final next = previous.revision + 1;
    _commit(chronicle, next, next, previous.sync);
    return chronicle;
  });

  /// Stores sync bookkeeping and an optional remote snapshot in one revision.
  bool replaceIfCurrent(
    int expectedRevision, {
    required Map<String, Object?> sync,
    Chronicle? snapshot,
  }) => _withWriteLock(() {
    final current = readRevision();
    if (current.revision != expectedRevision) return false;
    final next = current.revision + 1;
    _commit(
      snapshot ?? current.chronicle,
      next,
      snapshot == null ? current.dataRevision : next,
      sync,
    );
    return true;
  });

  T _withWriteLock<T>(T Function() operation) {
    directory.createSync(recursive: true);
    final location = directory.resolveSymbolicLinksSync();
    if (!_activeWrites.add(location)) {
      throw StateError('A local update is already in progress.');
    }
    try {
      final lock = File(_path('writer.lock')).openSync(mode: FileMode.append);
      try {
        lock.lockSync(FileLock.exclusive);
        return operation();
      } finally {
        lock.closeSync();
      }
    } finally {
      _activeWrites.remove(location);
    }
  }

  void _commit(
    Chronicle chronicle,
    int revision,
    int dataRevision,
    Map<String, Object?> sync,
  ) {
    final temporary = directory.createTempSync('.pending-');
    try {
      final staged = File.fromUri(temporary.uri.resolve('snapshot.json'));
      final document =
          jsonDecode(encodeChronicle(chronicle)) as Map<String, dynamic>;
      document['_local'] = {'dataRevision': dataRevision, 'sync': sync};
      staged.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(document)}\n',
        flush: true,
      );
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

  LocalChronicleRevision _read(int revision) {
    if (revision == 0) {
      return (
        revision: 0,
        dataRevision: 0,
        chronicle: Chronicle(),
        sync: const {},
      );
    }
    final text = File(_path('revision-$revision.json')).readAsStringSync();
    final chronicle = decodeChronicle(text);
    final metadata = (jsonDecode(text) as Map<String, dynamic>)['_local'];
    if (metadata == null) {
      return (
        revision: revision,
        dataRevision: revision,
        chronicle: chronicle,
        sync: const {},
      );
    }
    if (metadata is! Map<String, dynamic> ||
        metadata['dataRevision'] is! int ||
        metadata['sync'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid local snapshot metadata.');
    }
    final dataRevision = metadata['dataRevision'] as int;
    if (dataRevision < 0 || dataRevision > revision) {
      throw const FormatException('Invalid local data revision.');
    }
    return (
      revision: revision,
      dataRevision: dataRevision,
      chronicle: chronicle,
      sync: Map.unmodifiable(metadata['sync'] as Map<String, dynamic>),
    );
  }

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

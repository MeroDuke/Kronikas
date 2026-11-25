import 'kronikas_core.dart';
import 'local_chronicle_store.dart';
import 'src/chronicle_json.dart';
import 'src/chronicle_merge.dart';

export 'src/chronicle_merge.dart' show MergeConflict;

final class SyncConflictReview {
  SyncConflictReview._(
    this._owner,
    this.localRevision,
    this.remoteCommit,
    this._base,
    this._local,
    this._remote,
    this.conflicts,
    this.requiresSnapshot,
  );

  final ChronicleSync _owner;
  final int localRevision;
  final String remoteCommit;
  final Chronicle? _base;
  final Chronicle _local;
  final Chronicle? _remote;
  final List<MergeConflict> conflicts;
  final bool requiresSnapshot;

  Chronicle get localVersion => decodeChronicle(encodeChronicle(_local));
  Chronicle? get remoteVersion =>
      _remote == null ? null : decodeChronicle(encodeChronicle(_remote));
}

typedef SyncResolutionBackup = ({int localRevision, String remoteCommit});

enum SyncOutcome { upToDate, downloaded, uploaded, conflict, localChanged }

abstract interface class ChronicleRemote {
  String get identity;
  Future<String> head();
  Future<String?> readSnapshot(String commit);
  Future<String> prepareCommit(String parent, String snapshot);
  Future<bool> containsCommit(String head, String commit);
  Future<void> advance(String commit);
}

final class RemoteWriteRejected implements Exception {
  const RemoteWriteRejected();
}

/// Synchronizes one local directory with one remote location on explicit request.
final class ChronicleSync {
  ChronicleSync(this.local, this.remote);

  final LocalChronicleStore local;
  final ChronicleRemote remote;

  Future<SyncOutcome> synchronize() async {
    final current = local.readRevision();
    final metadata = current.sync;
    final bound = metadata['remote'];
    _verifyRemote(current);
    final base = metadata['base'] as String?;
    final clean = metadata['clean'] as int? ?? 0;
    final pending = metadata['pending'] as String?;
    final head = await remote.head();

    if (pending != null) {
      final pendingRevision = metadata['pendingRevision'] as int;
      if (head == pending ||
          (head != base && await remote.containsCommit(head, pending))) {
        return _finish(pending, pendingRevision);
      }
      if (head != base) return SyncOutcome.conflict;
      return _advance(pending, pendingRevision, head);
    }

    final localText = encodeChronicle(current.chronicle);
    final hasLocalData =
        current.chronicle.campaigns.isNotEmpty ||
        current.chronicle.adventures.isNotEmpty;
    final dirty = bound == null ? hasLocalData : current.dataRevision != clean;

    if (head != base || bound == null) {
      final remoteText = await remote.readSnapshot(head);
      if (remoteText != null) {
        final incoming = decodeChronicle(remoteText);
        final same = encodeChronicle(incoming) == localText;
        if (dirty && !same) {
          if (base == null || !await remote.containsCommit(head, base)) {
            return SyncOutcome.conflict;
          }
          final baseText = await remote.readSnapshot(base);
          if (baseText == null) return SyncOutcome.conflict;
          final merged = mergeChronicles(
            decodeChronicle(baseText),
            current.chronicle,
            incoming,
          );
          if (merged == null) return SyncOutcome.conflict;
          return _upload(current, head, clean, merged: merged);
        }
        final acceptedRevision = same
            ? current.dataRevision
            : current.revision + 1;
        final saved = local.replaceIfCurrent(
          current.revision,
          sync: _metadata(head, acceptedRevision, metadata),
          snapshot: same ? null : incoming,
        );
        if (!saved) return SyncOutcome.localChanged;
        return same ? SyncOutcome.upToDate : SyncOutcome.downloaded;
      }
      if (bound != null) return SyncOutcome.conflict;
      if (!dirty) return SyncOutcome.upToDate;
    }

    if (!dirty) return SyncOutcome.upToDate;
    return _upload(current, head, clean);
  }

  Future<SyncConflictReview> reviewConflict() async {
    final current = local.readRevision();
    _verifyRemote(current);
    final head = await remote.head();
    final incoming = await remote.readSnapshot(head);
    final base = current.sync['base'] as String?;
    final baseText = base != null && await remote.containsCommit(head, base)
        ? await remote.readSnapshot(base)
        : null;
    final original = baseText == null ? null : decodeChronicle(baseText);
    final published = incoming == null ? null : decodeChronicle(incoming);
    final conflicts = <MergeConflict>[];
    final merged = original != null && published != null
        ? mergeChronicles(
            original,
            current.chronicle,
            published,
            resolve: (item) {
              conflicts.add(item);
              return item.local;
            },
          )
        : null;
    return SyncConflictReview._(
      this,
      current.revision,
      head,
      original,
      current.chronicle,
      published,
      List.unmodifiable(conflicts),
      merged == null,
    );
  }

  /// Resolve with JSON values in review order, or a validated snapshot for a
  /// structural conflict. A null selection represents a deleted record.
  Future<SyncOutcome> resolveConflict(
    SyncConflictReview review, {
    List<String?> selections = const [],
    Chronicle? snapshot,
  }) async {
    if (!identical(review._owner, this)) {
      throw ArgumentError('Conflict review belongs to a different sync.');
    }
    final current = local.readRevision();
    _verifyRemote(current);
    if (current.revision != review.localRevision)
      return SyncOutcome.localChanged;
    if (await remote.head() != review.remoteCommit) return SyncOutcome.conflict;

    Chronicle? resolved;
    if (snapshot != null && review.requiresSnapshot && selections.isEmpty) {
      resolved = decodeChronicle(encodeChronicle(snapshot));
    } else if (snapshot == null &&
        !review.requiresSnapshot &&
        review.conflicts.isNotEmpty &&
        selections.length == review.conflicts.length) {
      var index = 0;
      resolved = mergeChronicles(
        review._base!,
        review._local,
        review._remote!,
        resolve: (_) => selections[index++],
      );
    }
    if (resolved == null) throw ArgumentError('Invalid conflict resolution.');

    final commit = await remote.prepareCommit(
      review.remoteCommit,
      encodeChronicle(resolved),
    );
    if (await remote.head() != review.remoteCommit) return SyncOutcome.conflict;
    if (!local.replaceIfCurrent(
      current.revision,
      sync: {
        ..._metadata(
          review.remoteCommit,
          current.sync['clean'] as int? ?? 0,
          current.sync,
        ),
        'pending': commit,
        'pendingRevision': current.dataRevision,
        'pendingResolution': encodeChronicle(resolved),
        'resolutionBackups': [
          ..._backupEntries(current.sync),
          {
            'localRevision': review.localRevision,
            'remoteCommit': review.remoteCommit,
            'remoteSnapshot': review._remote == null
                ? null
                : encodeChronicle(review._remote),
          },
        ],
      },
    ))
      return SyncOutcome.localChanged;
    return _advance(commit, current.dataRevision, review.remoteCommit);
  }

  List<SyncResolutionBackup> listResolutionBackups() {
    final current = local.readRevision();
    _verifyRemote(current);
    return List.unmodifiable(
      _backupEntries(current.sync).map(_backupReference),
    );
  }

  /// Returns an independent copy of the selected original version.
  Future<Chronicle?> restoreResolutionBackup(
    SyncResolutionBackup backup, {
    required bool fromRemote,
  }) async {
    final current = local.readRevision();
    _verifyRemote(current);
    for (final entry in _backupEntries(current.sync)) {
      if (_backupReference(entry) != backup) continue;
      if (!fromRemote) return local.openRevision(backup.localRevision);
      final snapshot = entry['remoteSnapshot'] as String?;
      return snapshot == null ? null : decodeChronicle(snapshot);
    }
    throw ArgumentError('Unknown conflict backup.');
  }

  Iterable<Map<String, Object?>> _backupEntries(Map<String, Object?> sync) =>
      (sync['resolutionBackups'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>();

  SyncResolutionBackup _backupReference(Map<String, Object?> entry) => (
    localRevision: entry['localRevision'] as int,
    remoteCommit: entry['remoteCommit'] as String,
  );

  void _verifyRemote(LocalChronicleRevision current) {
    final bound = current.sync['remote'];
    if (bound != null && bound != remote.identity) {
      throw StateError('The local store belongs to a different remote.');
    }
  }

  Future<SyncOutcome> _upload(
    LocalChronicleRevision current,
    String head,
    int clean, {
    Chronicle? merged,
  }) async {
    final commit = await remote.prepareCommit(
      head,
      encodeChronicle(merged ?? current.chronicle),
    );
    final pendingRevision = merged == null
        ? current.dataRevision
        : current.revision + 1;
    if (!local.replaceIfCurrent(
      current.revision,
      sync: {
        ..._metadata(head, clean, current.sync),
        'pending': commit,
        'pendingRevision': pendingRevision,
      },
      snapshot: merged,
    )) {
      return SyncOutcome.localChanged;
    }
    return _advance(commit, pendingRevision, head);
  }

  Future<SyncOutcome> _advance(
    String candidate,
    int dataRevision,
    String parent,
  ) async {
    if (await remote.head() != parent) return SyncOutcome.conflict;
    try {
      await remote.advance(candidate);
    } on RemoteWriteRejected {
      if (await remote.head() != parent) return SyncOutcome.conflict;
      rethrow;
    }
    return _finish(candidate, dataRevision);
  }

  SyncOutcome _finish(String candidate, int dataRevision) {
    final current = local.readRevision();
    if (current.sync['pending'] != candidate) return SyncOutcome.localChanged;
    final pendingResolution = current.sync['pendingResolution'] as String?;
    final installResolution =
        pendingResolution != null && current.dataRevision == dataRevision;
    final localChanged = pendingResolution != null && !installResolution;
    final clean = pendingResolution == null
        ? dataRevision
        : installResolution
        ? current.revision + 1
        : -1;
    if (!local.replaceIfCurrent(
      current.revision,
      sync: _metadata(
        localChanged ? current.sync['base'] as String : candidate,
        clean,
        current.sync,
      ),
      snapshot: installResolution ? decodeChronicle(pendingResolution) : null,
    )) {
      return SyncOutcome.localChanged;
    }
    return localChanged ? SyncOutcome.localChanged : SyncOutcome.uploaded;
  }

  Map<String, Object?> _metadata(
    String commit,
    int clean,
    Map<String, Object?> previous,
  ) => {
    'remote': remote.identity,
    'base': commit,
    'clean': clean,
    if (previous.containsKey('resolutionBackups'))
      'resolutionBackups': previous['resolutionBackups'],
  };
}

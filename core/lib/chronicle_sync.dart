import 'kronikas_core.dart';
import 'local_chronicle_store.dart';
import 'src/chronicle_json.dart';
import 'src/chronicle_merge.dart';

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
    if (bound != null && bound != remote.identity) {
      throw StateError('The local store belongs to a different remote.');
    }
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
          sync: _metadata(head, acceptedRevision),
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
        ..._metadata(head, clean),
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
    if (!local.replaceIfCurrent(
      current.revision,
      sync: _metadata(candidate, dataRevision),
    )) {
      return SyncOutcome.localChanged;
    }
    return SyncOutcome.uploaded;
  }

  Map<String, Object?> _metadata(String commit, int clean) => {
    'remote': remote.identity,
    'base': commit,
    'clean': clean,
  };
}

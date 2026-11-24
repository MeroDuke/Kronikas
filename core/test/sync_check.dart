import 'dart:async';
import 'dart:io';

import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

final syncChecks = <String, Future<void> Function()>{
  'offline edits persist and competing clients keep both versions': _conflict,
  'lost write response and concurrent edit recover across reopen':
      _lostResponse,
};

Future<void> _conflict() async {
  await _withStores((first, second) async {
    final remote = _Remote();
    first.update((data) => data.createAdventure(id: 'a', title: 'Original'));
    remote.offline = true;
    try {
      await ChronicleSync(first, remote).synchronize();
      throw StateError('Expected offline error.');
    } on SocketException {
      _check(first.open().adventures['a']?.title == 'Original');
    }
    remote.offline = false;
    _check(
      await ChronicleSync(first, remote).synchronize() == SyncOutcome.uploaded,
    );
    _check(
      await ChronicleSync(second, remote).synchronize() ==
          SyncOutcome.downloaded,
    );
    _rename(first, 'First edit');
    _rename(second, 'Second edit');
    _check(
      await ChronicleSync(first, remote).synchronize() == SyncOutcome.uploaded,
    );
    final head = remote.current;
    _check(
      await ChronicleSync(second, remote).synchronize() == SyncOutcome.conflict,
    );
    _check(remote.current == head);
    _check(second.open().adventures['a']?.title == 'Second edit');
    _check(first.open().adventures['a']?.title == 'First edit');
  });
}

Future<void> _lostResponse() async {
  await _withStores((first, second) async {
    final remote = _Remote();
    first.update((data) => data.createAdventure(id: 'a', title: 'Original'));
    remote.afterAdvance = () {
      remote.afterAdvance = null;
      _rename(first, 'Edit during upload');
      throw TimeoutException('Simulated lost response.');
    };
    try {
      await ChronicleSync(first, remote).synchronize();
      throw StateError('Expected a lost response.');
    } on TimeoutException {
      _check(first.readRevision().sync['pending'] == remote.current);
    }
    final reopened = LocalChronicleStore(first.directory);
    _check(
      await ChronicleSync(reopened, remote).synchronize() ==
          SyncOutcome.uploaded,
    );
    _check(remote.advances == 1);
    _check(
      await ChronicleSync(reopened, remote).synchronize() ==
          SyncOutcome.uploaded,
    );
    _check(remote.advances == 2);
    _check(
      await ChronicleSync(second, remote).synchronize() ==
          SyncOutcome.downloaded,
    );
    _check(second.open().adventures['a']?.title == 'Edit during upload');
    _check(
      await ChronicleSync(reopened, remote).synchronize() ==
          SyncOutcome.upToDate,
    );
  });
}

void _rename(LocalChronicleStore store, String title) {
  store.update(
    (data) => data.editAdventure('a', title: title, description: ''),
  );
}

Future<void> _withStores(
  Future<void> Function(LocalChronicleStore, LocalChronicleStore) action,
) async {
  final root = Directory.systemTemp.createTempSync('kronikas-sync-test-');
  try {
    await action(
      LocalChronicleStore(Directory.fromUri(root.uri.resolve('first/'))),
      LocalChronicleStore(Directory.fromUri(root.uri.resolve('second/'))),
    );
  } finally {
    root.deleteSync(recursive: true);
  }
}

void _check(bool success) {
  if (!success) throw StateError('Sync expectation failed.');
}

final class _Remote implements ChronicleRemote {
  var current = 'root';
  var advances = 0;
  var offline = false;
  void Function()? afterAdvance;
  final _commits = <String, ({String parent, String snapshot})>{};

  @override
  String get identity => 'synthetic-remote';

  @override
  Future<String> head() async {
    if (offline) throw const SocketException('Simulated offline connection.');
    return current;
  }

  @override
  Future<String?> readSnapshot(String commit) async =>
      _commits[commit]?.snapshot;

  @override
  Future<String> prepareCommit(String parent, String snapshot) async {
    final id = '${_commits.length + 1}';
    _commits[id] = (parent: parent, snapshot: snapshot);
    return id;
  }

  @override
  Future<bool> containsCommit(String head, String commit) async {
    for (
      String? cursor = head;
      cursor != null;
      cursor = _commits[cursor]?.parent
    ) {
      if (cursor == commit) return true;
    }
    return false;
  }

  @override
  Future<void> advance(String commit) async {
    if (_commits[commit]?.parent != current) throw const RemoteWriteRejected();
    current = commit;
    advances++;
    afterAdvance?.call();
  }
}

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/github_chronicle_remote.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

final syncChecks = <String, Future<void> Function()>{
  'repository address accepts user input and rejects other origins': _addresses,
  'offline edits persist and competing clients keep both versions': _conflict,
  'incompatible sessions preserve both client states': _incompatibleSessions,
  'independent edits survive synchronization on both clients': _independent,
  'manual conflict review rejects stale versions and restores originals':
      _resolve,
  'lost write response and concurrent edit recover across reopen':
      _lostResponse,
};

Future<void> _addresses() async {
  for (final address in [
    '  SampleOwner/sample-stories ',
    'https://github.com/SampleOwner/sample-stories.git/',
  ]) {
    final repo = parseGitHubRepository(address);
    _expect('Repository owner', repo.owner, 'SampleOwner');
    _expect('Repository name', repo.repository, 'sample-stories');
  }
  for (final address in [
    'http://github.com/owner/repo',
    'https://github.com.example/owner/repo',
    'https://user@github.com/owner/repo',
    'https://github.com/owner/repo?token=value',
    'https://github.com/owner/repo/tree/main',
    'https://github.com/owner/invalid%2Frepo',
  ]) {
    try {
      parseGitHubRepository(address);
      throw StateError('Invalid repository address was accepted.');
    } on FormatException {
      continue;
    }
  }
}

Future<void> _conflict() async {
  await _withStores((first, second) async {
    final remote = _Remote();
    first.update((data) => data.createAdventure(id: 'a', title: 'Original'));
    remote.offline = true;
    try {
      await ChronicleSync(first, remote).synchronize();
      throw StateError('Expected offline error.');
    } on SocketException {
      _expect(
        'Local title after offline sync',
        first.open().adventures['a']?.title,
        'Original',
      );
    }
    remote.offline = false;
    _expect(
      'First client initial sync',
      await ChronicleSync(first, remote).synchronize(),
      SyncOutcome.uploaded,
    );
    _expect(
      'Second client initial sync',
      await ChronicleSync(second, remote).synchronize(),
      SyncOutcome.downloaded,
    );
    _rename(first, 'First edit');
    _rename(second, 'Second edit');
    _expect(
      'First client publishes edit',
      await ChronicleSync(first, remote).synchronize(),
      SyncOutcome.uploaded,
    );
    final head = remote.current;
    _expect(
      'Second client detects conflict',
      await ChronicleSync(second, remote).synchronize(),
      SyncOutcome.conflict,
    );
    _expect('Remote head after conflict', remote.current, head);
    _expect(
      'Second client retains local edit',
      second.open().adventures['a']?.title,
      'Second edit',
    );
    _expect(
      'First client retains published edit',
      first.open().adventures['a']?.title,
      'First edit',
    );
  });
}

Future<void> _independent() async {
  await _withStores((first, second) async {
    final remote = _Remote();
    final firstSync = ChronicleSync(first, remote);
    final secondSync = ChronicleSync(second, remote);
    first.update((data) {
      data.createAdventure(id: 'a', title: 'Original');
      data.startSession('a', id: 's', startedAt: DateTime.utc(2026, 1, 1));
    });
    _expect(
      'Publish common base',
      await firstSync.synchronize(),
      SyncOutcome.uploaded,
    );
    _expect(
      'Read common base',
      await secondSync.synchronize(),
      SyncOutcome.downloaded,
    );
    _rename(first, 'Revised title');
    second.update((data) {
      data.recordImprovisedEvent(
        'a',
        's',
        id: 'e',
        description: 'Crossed the river',
      );
    });
    _expect(
      'Publish title',
      await firstSync.synchronize(),
      SyncOutcome.uploaded,
    );
    _expect(
      'Publish merged state',
      await secondSync.synchronize(),
      SyncOutcome.uploaded,
    );
    _expect(
      'Download merged state',
      await firstSync.synchronize(),
      SyncOutcome.downloaded,
    );
    for (final store in [first, second]) {
      final adventure = LocalChronicleStore(store.directory)
          .open()
          .adventures['a']!;
      _expect('Merged title', adventure.title, 'Revised title');
      _expect(
        'Merged event',
        adventure.sessions['s']!.events.single.description,
        'Crossed the river',
      );
    }
  });
}

Future<void> _incompatibleSessions() async {
  await _withStores((first, second) async {
    final remote = _Remote();
    final firstSync = ChronicleSync(first, remote);
    final secondSync = ChronicleSync(second, remote);
    first.update((data) => data.createAdventure(id: 'a', title: 'Original'));
    await firstSync.synchronize();
    await secondSync.synchronize();
    first.update(
      (data) => data.startSession(
        'a',
        id: 'first',
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    second.update(
      (data) => data.startSession(
        'a',
        id: 'second',
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await firstSync.synchronize();
    final head = remote.current;
    _expect(
      'Two open sessions conflict',
      await secondSync.synchronize(),
      SyncOutcome.conflict,
    );
    _expect('Remote head after invalid combination', remote.current, head);
    _expect(
      'Local session after conflict',
      second.open().adventures['a']!.sessions.keys.single,
      'second',
    );
    _expect(
      'Published session after conflict',
      first.open().adventures['a']!.sessions.keys.single,
      'first',
    );
  });
}

Future<void> _resolve() async {
  await _withStores((first, second) async {
    final remote = _Remote();
    final firstSync = ChronicleSync(first, remote);
    final secondSync = ChronicleSync(second, remote);
    first.update((data) => data.createAdventure(id: 'a', title: 'Base'));
    await firstSync.synchronize();
    await secondSync.synchronize();
    _rename(first, 'Published');
    _rename(second, 'Local');
    await firstSync.synchronize();
    _expect(
      'Conflict before review',
      await secondSync.synchronize(),
      SyncOutcome.conflict,
    );
    final staleLocal = await secondSync.reviewConflict();
    second.update((data) => data.saveAdventureNote('a', 'weather', 'Rain'));
    _expect(
      'Local change invalidates approval',
      await secondSync.resolveConflict(
        staleLocal,
        selections: [jsonEncode('Approved')],
      ),
      SyncOutcome.localChanged,
    );
    final staleRemote = await secondSync.reviewConflict();
    _rename(first, 'Latest published');
    await firstSync.synchronize();
    _expect(
      'Remote change invalidates approval',
      await secondSync.resolveConflict(
        staleRemote,
        selections: [jsonEncode('Approved')],
      ),
      SyncOutcome.conflict,
    );

    final review = await secondSync.reviewConflict();
    _expect(
      'Conflict path',
      review.conflicts.single.path.join('/'),
      'adventures/a/title',
    );
    _expect(
      'Local conflict value',
      jsonDecode(review.conflicts.single.local!),
      'Local',
    );
    _expect(
      'Remote conflict value',
      jsonDecode(review.conflicts.single.remote!),
      'Latest published',
    );
    _expect(
      'Publish manually entered title',
      await secondSync.resolveConflict(
        review,
        selections: [jsonEncode('Approved')],
      ),
      SyncOutcome.uploaded,
    );
    _expect(
      'Second client already clean',
      await secondSync.synchronize(),
      SyncOutcome.upToDate,
    );
    _expect(
      'First client reads resolution',
      await firstSync.synchronize(),
      SyncOutcome.downloaded,
    );
    for (final store in [first, second]) {
      final merged = store.open().adventures['a']!;
      _expect('Approved title', merged.title, 'Approved');
      _expect('Independent note preserved', merged.notes['weather'], 'Rain');
    }

    final reopened = ChronicleSync(
      LocalChronicleStore(second.directory),
      remote,
    );
    final backup = reopened.listResolutionBackups().single;
    final localOriginal = await reopened.restoreResolutionBackup(
      backup,
      fromRemote: false,
    );
    final remoteOriginal = await reopened.restoreResolutionBackup(
      backup,
      fromRemote: true,
    );
    _expect(
      'Recovered local original',
      localOriginal?.adventures['a']?.title,
      'Local',
    );
    _expect(
      'Recovered remote original',
      remoteOriginal?.adventures['a']?.title,
      'Latest published',
    );
    _expect(
      'Restore preserves approved state',
      second.open().adventures['a']?.title,
      'Approved',
    );
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
      _expect(
        'Pending commit after lost response',
        first.readRevision().sync['pending'],
        remote.current,
      );
    }
    final reopened = LocalChronicleStore(first.directory);
    _expect(
      'First recovery sync',
      await ChronicleSync(reopened, remote).synchronize(),
      SyncOutcome.uploaded,
    );
    _expect('Remote writes after recovering lost response', remote.advances, 1);
    _expect(
      'Second recovery sync',
      await ChronicleSync(reopened, remote).synchronize(),
      SyncOutcome.uploaded,
    );
    _expect(
      'Remote writes after publishing concurrent edit',
      remote.advances,
      2,
    );
    _expect(
      'Second client downloads concurrent edit',
      await ChronicleSync(second, remote).synchronize(),
      SyncOutcome.downloaded,
    );
    _expect(
      'Downloaded title',
      second.open().adventures['a']?.title,
      'Edit during upload',
    );
    _expect(
      'First client final sync',
      await ChronicleSync(reopened, remote).synchronize(),
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

void _expect(String context, Object? actual, Object? expected) {
  if (actual != expected) {
    throw StateError('$context: expected <$expected>, got <$actual>.');
  }
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

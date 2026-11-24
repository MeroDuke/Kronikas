import 'dart:async';
import 'dart:io';

import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/github_chronicle_remote.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

Future<void> main(List<String> args) async {
  final token = Platform.environment['KRONIKAS_SYNC_TOKEN'];
  if (args.length != 4 || token == null || token.isEmpty) {
    stderr.writeln('Usage: github_sync_probe.dart OWNER REPO BRANCH DIRECTORY');
    stderr.writeln(
      'Set KRONIKAS_SYNC_TOKEN for the isolated private test repo.',
    );
    exitCode = 64;
    return;
  }
  final client = HttpClient();
  final root = Directory.systemTemp.createTempSync('kronikas-github-probe-');
  try {
    final remote = GitHubChronicleRemote(
      owner: args[0],
      repository: args[1],
      branch: args[2],
      directory: args[3],
      token: () async => token,
      client: client,
    );
    _expect(
      await remote.readSnapshot(await remote.head()) == null,
      'Empty probe directory',
    );
    final first = LocalChronicleStore(
      Directory.fromUri(root.uri.resolve('first/')),
    );
    final second = LocalChronicleStore(
      Directory.fromUri(root.uri.resolve('second/')),
    );
    first.update(
      (data) => data.createAdventure(id: 'synthetic', title: 'Original'),
    );
    final firstSync = ChronicleSync(first, remote);
    final secondSync = ChronicleSync(second, remote);
    try {
      await ChronicleSync(first, _LoseResponse(remote)).synchronize();
      throw StateError('Expected simulated response loss.');
    } on TimeoutException {
      _expect(
        first.readRevision().sync['pending'] != null,
        'Pending upload persisted',
      );
    }
    _expect(
      await firstSync.synchronize() == SyncOutcome.uploaded,
      'Recognized remote commit',
    );
    _expect(
      await secondSync.synchronize() == SyncOutcome.downloaded,
      'Second client loaded both files',
    );
    _rename(first, 'First client');
    _rename(second, 'Second client');
    _expect(
      await firstSync.synchronize() == SyncOutcome.uploaded,
      'First client uploaded',
    );
    final retained = await remote.head();
    _expect(
      await secondSync.synchronize() == SyncOutcome.conflict,
      'Second client reports conflict',
    );
    _expect(await remote.head() == retained, 'Remote commit retained');
    _expect(
      second.open().adventures['synthetic']?.title == 'Second client',
      'Second client retained its edit',
    );
  } finally {
    client.close(force: true);
    root.deleteSync(recursive: true);
  }
}

void _rename(LocalChronicleStore local, String title) {
  local.update(
    (data) => data.editAdventure('synthetic', title: title, description: ''),
  );
}

void _expect(bool check, String test) {
  if (!check) throw StateError(test);
  stdout.writeln('PASS $test');
}

final class _LoseResponse implements ChronicleRemote {
  _LoseResponse(this.remote);
  final ChronicleRemote remote;

  @override
  String get identity => remote.identity;

  @override
  Future<String> head() => remote.head();

  @override
  Future<String?> readSnapshot(String commit) => remote.readSnapshot(commit);

  @override
  Future<String> prepareCommit(String parent, String snapshot) =>
      remote.prepareCommit(parent, snapshot);

  @override
  Future<bool> containsCommit(String head, String commit) =>
      remote.containsCommit(head, commit);

  @override
  Future<void> advance(String commit) async {
    await remote.advance(commit);
    throw TimeoutException(
      'Simulated interruption after the successful ref update.',
    );
  }
}

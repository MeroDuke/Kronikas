import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_core/story_storage_sync.dart';
import 'package:kronikas_platform_probe/story_storage_preview.dart';

void main() {
  test('syncs only changed stories and preserves offline conflicts', () async {
    final temp = Directory.systemTemp.createTempSync('kronikas-story-sync-');
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory folder(String name) =>
        Directory.fromUri(temp.uri.resolve('$name/'));
    final first = LocalChronicleStore(folder('first'));
    final second = LocalChronicleStore(folder('second'));
    final remote = _ObservedStorage(StoryStoragePreview(folder('remote')));
    StoryStorageSync client(LocalChronicleStore store) =>
        StoryStorageSync(store, remote);
    final a = client(first);
    final b = client(second);

    first.update((data) {
      data.createAdventure(id: 'one', title: 'One');
      data.createAdventure(id: 'two', title: 'Two');
    });
    expect(await a.synchronize(download: false), StorySyncResult.complete);
    expect(remote.writes, ['one', 'two']);
    expect(await b.synchronize(), StorySyncResult.complete);
    expect(second.open().adventures.keys, unorderedEquals(['one', 'two']));
    expect(remote.reads, unorderedEquals(['one', 'two']));
    remote.reads.clear();
    remote.writes.clear();
    expect(await b.synchronize(), StorySyncResult.complete);
    expect(remote.reads, isEmpty);
    expect(remote.writes, isEmpty);

    void change(LocalChronicleStore store, String id) =>
        store.update((data) => data.addMilestone('one', id: id, title: id));

    remote.offline = true;
    change(first, 'offline');
    expect(await a.synchronize(download: false), StorySyncResult.pending);
    expect(first.open().adventures['one']!.milestones.keys, ['offline']);
    remote.offline = false;
    expect(await client(first).synchronize(), StorySyncResult.complete);
    expect(remote.writes, ['one']);
    expect(await b.synchronize(), StorySyncResult.complete);
    expect(remote.reads, ['one']);
    expect(second.open().adventures['one']!.milestones.keys, ['offline']);

    change(first, 'local');
    change(second, 'remote');
    expect(await b.synchronize(download: false), StorySyncResult.complete);
    expect(await a.synchronize(), StorySyncResult.conflict);
    expect(first.open().adventures['one']!.milestones.keys, [
      'offline',
      'local',
    ]);
    expect(second.open().adventures['one']!.milestones.keys, [
      'offline',
      'remote',
    ]);
  });
}

final class _ObservedStorage implements StoryStorage {
  _ObservedStorage(this.inner);
  final StoryStorage inner;
  final reads = <String>[];
  final writes = <String>[];
  bool offline = false;

  @override
  String get identity => inner.identity;

  @override
  Future<Map<String, String>> listVersions() async {
    if (offline) throw const SocketException('Offline.');
    return inner.listVersions();
  }

  @override
  Future<String> read(String id, String version) {
    reads.add(id);
    return inner.read(id, version);
  }

  @override
  Future<String?> write(String id, String? expectedVersion, String snapshot) {
    writes.add(id);
    return inner.write(id, expectedVersion, snapshot);
  }
}

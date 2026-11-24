import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_platform_probe/story_picker.dart';

void main() {
  final directory = Directory.systemTemp.createTempSync(
    'kronikas-walkthrough-',
  );
  final local = LocalChronicleStore(
    Directory.fromUri(directory.uri.resolve('local/')),
  );
  final publisher = LocalChronicleStore(
    Directory.fromUri(directory.uri.resolve('publisher/')),
  );
  final remote = _WalkthroughRemote();
  final sync = ChronicleSync(local, remote);
  final publisherSync = ChronicleSync(publisher, remote);
  Future<Chronicle>? seed;
  runApp(
    StoryPickerApp(
      testRemoteEdit: () async {
        publisher.update(
          (draft) => draft.editAdventure(
            'synthetic',
            title: 'Friss távoli átkelés',
            description: 'Szintetikus próbatörténet.',
          ),
        );
        await publisherSync.synchronize();
      },
      testForm: (address: 'example/stories', token: 'github_pat_synthetic'),
      load: (address, branch, token) async {
        if (address != 'example/stories' ||
            branch != null ||
            token != 'github_pat_synthetic') {
          throw const FormatException('Unexpected walkthrough input.');
        }
        return (
          branch: 'main',
          stories: const [
            (title: 'Teszt mese', directory: 'stories/test-mese'),
          ],
          openSync: (_) async => (sync: sync, close: () {}),
          open: (story) => seed ??= () async {
            final start = DateTime.utc(2026, 11, 24, 18);
            publisher.update(
              (draft) => draft
                ..createAdventure(
                  id: 'synthetic',
                  title: story.title,
                  description: 'Szintetikus próbatörténet.',
                )
                ..startSession('synthetic', id: 'first', startedAt: start)
                ..recordImprovisedEvent(
                  'synthetic',
                  'first',
                  id: 'river',
                  description: 'A csapat átkelt a folyón.',
                )
                ..closeSession(
                  'synthetic',
                  'first',
                  start.add(const Duration(hours: 2)),
                ),
            );
            await publisherSync.synchronize();
            await sync.synchronize();
            final initial = local.open();
            publisher.update(
              (draft) => draft.editAdventure(
                'synthetic',
                title: 'Távoli átkelés',
                description: 'Szintetikus próbatörténet.',
              ),
            );
            await publisherSync.synchronize();
            local.update(
              (draft) => draft.editAdventure(
                'synthetic',
                title: 'Helyi átkelés',
                description: 'Szintetikus próbatörténet.',
              ),
            );
            return initial;
          }(),
        );
      },
    ),
  );
}

class _WalkthroughRemote implements ChronicleRemote {
  final _commits = <String, ({String parent, String content})>{};
  var _head = 'root';

  @override
  String get identity => 'walkthrough';

  @override
  Future<String> head() async => _head;

  @override
  Future<String?> readSnapshot(String commit) async =>
      _commits[commit]?.content;

  @override
  Future<String> prepareCommit(String parent, String snapshot) async {
    final id = '${_commits.length + 1}';
    _commits[id] = (parent: parent, content: snapshot);
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
    if (_commits[commit]?.parent != _head) throw const RemoteWriteRejected();
    _head = commit;
  }
}

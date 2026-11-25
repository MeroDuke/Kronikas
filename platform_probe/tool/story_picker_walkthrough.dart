import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_platform_probe/conflict_panel.dart';

void main() => runApp(
  buildWalkthroughApp(
    Directory.systemTemp.createTempSync('kronikas-walkthrough-'),
  ),
);

Widget buildWalkthroughApp(Directory directory) =>
    MaterialApp(home: _Walkthrough(directory: directory));

class _Walkthrough extends StatefulWidget {
  const _Walkthrough({required this.directory});

  final Directory directory;

  @override
  State<_Walkthrough> createState() => _WalkthroughState();
}

class _WalkthroughState extends State<_Walkthrough> {
  static const storyTitle = 'Teszt mese';
  late final local = LocalChronicleStore(
    Directory.fromUri(widget.directory.uri.resolve('local/')),
  );
  late final publisher = LocalChronicleStore(
    Directory.fromUri(widget.directory.uri.resolve('publisher/')),
  );
  final remote = _WalkthroughRemote();
  late final sync = ChronicleSync(local, remote);
  late final publisherSync = ChronicleSync(publisher, remote);
  Future<Chronicle>? seed;
  Chronicle? story;
  bool opening = false;

  Future<Chronicle> _seed() async {
    final start = DateTime.utc(2026, 11, 24, 18);
    publisher.update(
      (draft) => draft
        ..createAdventure(
          id: 'synthetic',
          title: storyTitle,
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
  }

  Future<void> _open() async {
    setState(() => opening = true);
    final initial = await (seed ??= _seed());
    if (mounted) {
      setState(() {
        story = initial;
        opening = false;
      });
    }
  }

  Future<void> _editRemote() async {
    publisher.update(
      (draft) => draft.editAdventure(
        'synthetic',
        title: 'Friss távoli átkelés',
        description: 'Szintetikus próbatörténet.',
      ),
    );
    await publisherSync.synchronize();
  }

  @override
  Widget build(BuildContext context) {
    final opened = story;
    return Scaffold(
      appBar: AppBar(title: const Text('Krónikás')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (opened == null) ...[
                Text('Mesék', style: Theme.of(context).textTheme.headlineSmall),
                ListTile(
                  title: const Text(storyTitle),
                  onTap: opening ? null : _open,
                ),
              ] else ...[
                Text(
                  storyTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                for (final adventure in opened.adventures.values)
                  _AdventureHistory(
                    adventure: adventure,
                    showTitle: adventure.title != storyTitle,
                  ),
                ConflictPanel(
                  sync: sync,
                  testRemoteEdit: _editRemote,
                  onChanged: () => setState(() => story = local.open()),
                ),
                TextButton(
                  onPressed: () => setState(() => story = null),
                  child: const Text('Vissza a mesékhez'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdventureHistory extends StatelessWidget {
  const _AdventureHistory({required this.adventure, required this.showTitle});

  final Adventure adventure;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final sessions = adventure.sessions.values;
    final dates = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle || adventure.description.isNotEmpty)
          ListTile(
            title: showTitle ? Text(adventure.title) : null,
            subtitle: adventure.description.isEmpty
                ? null
                : Text(adventure.description),
          ),
        if (sessions.isEmpty)
          const ListTile(title: Text('Még nincs rögzített játékalkalom.')),
        for (final session in sessions)
          ExpansionTile(
            key: ValueKey((adventure.id, session.id)),
            title: Text(
              session.isOpen ? 'Nyitott játékalkalom' : 'Lezárt játékalkalom',
            ),
            subtitle: Text(
              dates.formatCompactDate(session.startedAt.toLocal()),
            ),
            children: [
              if (session.events.isEmpty)
                const ListTile(
                  title: Text('Ehhez az alkalomhoz nincs esemény.'),
                ),
              for (final event in session.events)
                ListTile(
                  title: Text(event.description),
                  subtitle: Text(
                    event.visibility == EventVisibility.gmOnly
                        ? 'Csak a mesélőnek'
                        : 'Publikálható',
                  ),
                ),
            ],
          ),
      ],
    );
  }
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

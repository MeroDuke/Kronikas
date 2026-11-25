import 'dart:async';
import 'dart:io';
import 'dart:convert';

// The pinned Flutter SDK provides this UI without an additional package.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

import 'conflict_panel.dart';

import 'package:kronikas_core/github_chronicle_remote.dart';
import 'package:kronikas_core/kronikas_core.dart';

typedef StorySync = ({ChronicleSync sync, void Function() close});

typedef StoryCatalog = ({
  String branch,
  List<GitHubStory> stories,
  Future<Chronicle> Function(GitHubStory) open,
  Future<StorySync> Function(GitHubStory) openSync,
});
typedef CatalogLoader = Future<StoryCatalog> Function(
  String address,
  String? branch,
  String token,
);

void main() => runApp(const StoryPickerApp(load: _loadGitHub));

Future<StoryCatalog> _loadGitHub(
  String address,
  String? branch,
  String token,
) async {
  if (!token.startsWith('github_pat_')) {
    throw const FormatException('Repóra korlátozott GitHub-token szükséges.');
  }
  final client = HttpClient();
  try {
    final repo = await GitHubChronicleRemote.connect(
      address: address,
      branch: branch,
      token: () async => token,
      client: client,
    );
    final stories = await repo.listStories();
    return (
      branch: repo.branch,
      stories: stories,
      openSync: (story) async {
        final path = Platform.isWindows
            ? Platform.environment['LOCALAPPDATA']
            : await const MethodChannel(
                'hu.akihabarai.kronikas_platform_probe/storage',
              ).invokeMethod<String>('storagePath');
        if (path == null)
          throw StateError('Application directory unavailable.');
        final identity = jsonEncode([
          repo.owner.toLowerCase(),
          repo.repository.toLowerCase(),
          repo.branch,
          story.directory,
        ]);
        final key = base64Url.encode(utf8.encode(identity));
        final store = LocalChronicleStore(
          Directory.fromUri(
            Directory(path).absolute.uri.resolve('KronikasStories/$key/'),
          ),
        );
        final client = HttpClient();
        final selected = GitHubChronicleRemote(
          owner: repo.owner,
          repository: repo.repository,
          branch: repo.branch,
          directory: '',
          token: () async => token,
          client: client,
        ).forStory(story);
        return (
          sync: ChronicleSync(store, selected),
          close: () => client.close(force: true),
        );
      },
      open: (story) async {
        final client = HttpClient();
        try {
          final connection = GitHubChronicleRemote(
            owner: repo.owner,
            repository: repo.repository,
            branch: repo.branch,
            directory: '',
            token: () async => token,
            client: client,
          );
          return await connection.openStory(story);
        } finally {
          client.close(force: true);
        }
      },
    );
  } finally {
    client.close(force: true);
  }
}

class StoryPickerApp extends StatelessWidget {
  const StoryPickerApp({
    super.key,
    required this.load,
    this.testForm,
    this.testRemoteEdit,
  });

  final CatalogLoader load;
  final ({String address, String token})? testForm;
  final Future<void> Function()? testRemoteEdit;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Krónikás',
    theme: ThemeData(colorSchemeSeed: const Color(0xff355e58)),
    home: _StoryPicker(
      load: load,
      testForm: testForm,
      testRemoteEdit: testRemoteEdit,
    ),
  );
}

class _StoryPicker extends StatefulWidget {
  const _StoryPicker({required this.load, this.testForm, this.testRemoteEdit});

  final CatalogLoader load;
  final ({String address, String token})? testForm;
  final Future<void> Function()? testRemoteEdit;

  @override
  State<_StoryPicker> createState() => _StoryPickerState();
}

class _StoryPickerState extends State<_StoryPicker> {
  late final _repository = TextEditingController(
    text: widget.testForm?.address,
  );
  final _branch = TextEditingController();
  late final _token = TextEditingController(text: widget.testForm?.token);
  StoryCatalog? _catalog;
  Chronicle? _story;
  String? _storyTitle;
  StorySync? _storySync;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _storySync?.close();
    _repository.dispose();
    _branch.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GitHubSyncException catch (error) {
      if (mounted)
        setState(
          () => _error = switch (error.statusCode) {
            401 || 403 => 'Ellenőrizd a token érvényességét és hozzáférését.',
            404 => 'A repó vagy az ág nem érhető el ezzel a tokennel.',
            _ => 'A GitHub nem tudta teljesíteni a kérést.',
          },
        );
    } on SocketException {
      if (mounted) setState(() => _error = 'A GitHub hálózaton nem érhető el.');
    } on TimeoutException {
      if (mounted)
        setState(() => _error = 'A GitHub-kérés időtúllépés miatt megszakadt.');
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Ellenőrizd a privát GitHub-repó címét, az ágat és a mesék formátumát.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final address = _repository.text.trim();
    final branch = _branch.text.trim();
    final token = _token.text.trim();
    if (address.isEmpty || token.isEmpty) {
      setState(() => _error = 'Add meg a repó címét és a GitHub-tokent.');
      return;
    }
    if (!token.startsWith('github_pat_')) {
      setState(() => _error = 'Repóra korlátozott GitHub-token szükséges.');
      return;
    }
    await _perform(() async {
      final catalog = await widget.load(
        address,
        branch.isEmpty ? null : branch,
        token,
      );
      if (!mounted) return;
      _token.clear();
      setState(() => _catalog = catalog);
    });
  }

  Future<void> _open(GitHubStory entry) => _perform(() async {
    final story = await _catalog!.open(entry);
    final connection = await _catalog!.openSync(entry);
    if (!mounted) {
      connection.close();
      return;
    }
    if (mounted)
      setState(() {
        _storySync = connection;
        _story = story;
        _storyTitle = entry.title;
      });
  });

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final catalog = _catalog;
    return Scaffold(
      appBar: AppBar(title: const Text('Krónikás')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error case final String error)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(liveRegion: true, child: Text(error)),
                ),
              if (story != null) ...[
                Text(
                  _storyTitle!,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                for (final adventure in story.adventures.values)
                  _AdventureHistory(
                    adventure: adventure,
                    showTitle: adventure.title != _storyTitle,
                  ),
                ConflictPanel(
                  sync: _storySync!.sync,
                  testRemoteEdit: widget.testRemoteEdit,
                  onChanged: () =>
                      setState(() => _story = _storySync!.sync.local.open()),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _storySync?.close();
                    _storySync = null;
                    _story = null;
                  }),
                  child: const Text('Vissza a mesékhez'),
                ),
              ] else if (catalog != null) ...[
                Text(
                  'Mesék · ${catalog.branch}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (catalog.stories.isEmpty)
                  const ListTile(
                    title: Text('Ezen az ágon még nincs megnyitható mese.'),
                  ),
                for (final entry in catalog.stories)
                  ListTile(
                    title: Text(entry.title),
                    subtitle: Text(entry.directory),
                    onTap: _busy ? null : () => _open(entry),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _catalog = null;
                          _error = null;
                        }),
                  child: const Text('Másik repó csatlakoztatása'),
                ),
              ] else ...[
                TextField(
                  controller: _repository,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'GitHub-repó címe',
                  ),
                ),
                TextField(
                  controller: _branch,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Ág (opcionális)',
                  ),
                ),
                TextField(
                  controller: _token,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Repóra korlátozott GitHub-token',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _connect,
                  child: const Text('Repó csatlakoztatása'),
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

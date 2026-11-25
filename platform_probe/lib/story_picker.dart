import 'dart:async';
import 'dart:convert';
import 'dart:io';

// The pinned Flutter SDK provides this UI without an additional package.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronikas_core/chronicle_sync.dart';
import 'package:kronikas_core/github_chronicle_remote.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

import 'conflict_panel.dart';
import 'github_sign_in.dart';
import 'local_adventures.dart';

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

void main() => runApp(
  StoryPickerApp(
    load: _loadGitHub,
    signIn: githubSignInConfigured ? connectGitHub : null,
  ),
);

Future<Uri> _storyStorageRoot() async {
  final directory = Platform.isWindows
      ? Platform.environment['LOCALAPPDATA']
      : await const MethodChannel(
          'hu.akihabarai.kronikas_platform_probe/storage',
        ).invokeMethod<String>('storagePath');
  if (directory == null) throw StateError('Application directory unavailable.');
  return Directory(directory).absolute.uri.resolve('KronikasStories/');
}

Future<StoryCatalog> _loadGitHub(
  String address,
  String? branch,
  String token,
) async {
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
        final identity = jsonEncode([
          repo.owner.toLowerCase(),
          repo.repository.toLowerCase(),
          repo.branch,
          story.directory,
        ]);
        final key = base64Url.encode(utf8.encode(identity));
        final store = LocalChronicleStore(
          Directory.fromUri((await _storyStorageRoot()).resolve('$key/')),
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
    this.signIn,
    this.testForm,
    this.testRemoteEdit,
  });

  final CatalogLoader load;
  final Future<GitHubConnection> Function()? signIn;
  final ({String address, String token})? testForm;
  final Future<void> Function()? testRemoteEdit;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Krónikás',
    theme: ThemeData(colorSchemeSeed: const Color(0xff355e58)),
    home: _StoryPicker(
      load: load,
      signIn: signIn,
      testForm: testForm,
      testRemoteEdit: testRemoteEdit,
    ),
  );
}

class _StoryPicker extends StatefulWidget {
  const _StoryPicker({
    required this.load,
    this.signIn,
    this.testForm,
    this.testRemoteEdit,
  });

  final CatalogLoader load;
  final Future<GitHubConnection> Function()? signIn;
  final ({String address, String token})? testForm;
  final Future<void> Function()? testRemoteEdit;

  @override
  State<_StoryPicker> createState() => _StoryPickerState();
}

class _StoryPickerState extends State<_StoryPicker> {
  GitHubConnection? _connection;
  StoryCatalog? _catalog;
  Chronicle? _story;
  String? _storyTitle;
  StorySync? _storySync;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _storySync?.close();
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
          () => _error = 'A GitHub-művelet sikertelen. Ellenőrizd a hozzáférést, majd próbáld újra.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLocal() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = LocalChronicleStore(
        Directory.fromUri((await _storyStorageRoot()).resolve('local/')),
      );
      final initial = store.open();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LocalAdventures(store: store, initial: initial),
        ),
      );
    } catch (_) {
      if (mounted)
        setState(() => _error = 'A helyi kalandok nem nyithatók meg.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _perform(() async {
    if (widget.testForm case final fixture?) {
      final catalog = await widget.load(fixture.address, null, fixture.token);
      if (mounted) setState(() => _catalog = catalog);
      return;
    }
    final connection = await widget.signIn!();
    if (mounted) setState(() => _connection = connection);
  });

  Future<void> _refreshRepositories() => _perform(() async {
    final token = _connection!.token;
    final repositories = await refreshGitHubRepositories(token);
    if (mounted)
      setState(() => _connection = (token: token, repositories: repositories));
  });

  Future<void> _selectRepository(String repository) => _perform(() async {
    final catalog = await widget.load(repository, null, _connection!.token);
    if (mounted) setState(() => _catalog = catalog);
  });

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
              ] else if (_connection case final connection?) ...[
                Text(
                  'GitHub-repók',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (connection.repositories.isEmpty) ...[
                  const Text('A Krónikás még nem fér hozzá privát repóhoz.'),
                  if (githubInstallConfigured)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(openGitHubInstallation),
                      child: const Text('Hozzáférés beállítása a GitHubon'),
                    ),
                  TextButton(
                    onPressed: _busy ? null : _refreshRepositories,
                    child: const Text('Repók frissítése'),
                  ),
                ],
                for (final repository in connection.repositories)
                  ListTile(
                    title: Text(repository),
                    onTap: _busy ? null : () => _selectRepository(repository),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _connection = null;
                          _error = null;
                        }),
                  child: const Text('GitHub leválasztása'),
                ),
              ] else ...[
                if (widget.testForm == null && widget.signIn == null)
                  const Text(
                    'A GitHub-belépés ehhez a buildhez még nincs beállítva.',
                  ),
                FilledButton(
                  onPressed:
                      _busy ||
                          (widget.testForm == null && widget.signIn == null)
                      ? null
                      : _connect,
                  child: Text(
                    widget.testForm == null
                        ? 'GitHub csatlakoztatása'
                        : 'Repó csatlakoztatása',
                  ),
                ),
                if (_busy && widget.testForm == null)
                  const Text(
                    'Hagyd jóvá a belépést a böngészőben, majd térj vissza ide.',
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : _openLocal,
                  child: const Text('Helyi kalandok'),
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

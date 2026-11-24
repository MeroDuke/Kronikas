import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chronicle_sync.dart';
import 'kronikas_core.dart';
import 'src/chronicle_json.dart';

typedef _Json = Map<String, dynamic>;

typedef GitHubStory = ({String directory, String title});

final class GitHubSyncException implements Exception {
  const GitHubSyncException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'GitHub sync request failed (HTTP $statusCode).';
}

/// Stores one Chronicle document and its manifest on an existing private branch.
final class GitHubChronicleRemote implements ChronicleRemote {
  /// Resolves a user-entered repository address and its default or chosen branch.
  static Future<GitHubChronicleRemote> connect({
    required String address,
    String? branch,
    required Future<String> Function() token,
    required HttpClient client,
  }) async {
    final location = parseGitHubRepository(address);
    final connection = GitHubChronicleRemote(
      owner: location.owner,
      repository: location.repository,
      branch: branch ?? 'HEAD',
      directory: '',
      token: token,
      client: client,
    );
    final info = await connection._privateRepository();
    return GitHubChronicleRemote(
      owner: location.owner,
      repository: location.repository,
      branch: branch ?? (info['default_branch'] as String),
      directory: '',
      token: token,
      client: client,
    );
  }

  GitHubChronicleRemote({
    required this.owner,
    required this.repository,
    required this.branch,
    required this.directory,
    required this.token,
    required this.client,
  }) {
    if (!_repoName.hasMatch(owner) ||
        !_repoName.hasMatch(repository) ||
        !_validParts(branch.split('/')) ||
        (directory.isNotEmpty && !_validParts(directory.split('/')))) {
      throw ArgumentError('Invalid GitHub repository location.');
    }
  }

  final String owner;
  final String repository;
  final String branch;
  final String directory;
  final Future<String> Function() token;
  final HttpClient client;

  static final _repoName = RegExp(r'^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$');
  static final _shaPattern = RegExp(r'^[a-f0-9]{40}$');
  static const _deadline = Duration(seconds: 20);
  static bool _validParts(List<String> parts) => parts.every(
    (part) =>
        part.isNotEmpty &&
        part != '.' &&
        part != '..' &&
        !part.contains(RegExp(r'[\\\x00-\x1f\x7f]')),
  );

  @override
  String get identity => jsonEncode([
    'github.com',
    owner.toLowerCase(),
    repository.toLowerCase(),
    branch,
    directory,
  ]);

  GitHubChronicleRemote forStory(GitHubStory story) => GitHubChronicleRemote(
    owner: owner,
    repository: repository,
    branch: branch,
    directory: story.directory,
    token: token,
    client: client,
  );

  Future<Chronicle> openStory(GitHubStory story) async {
    final selected = forStory(story);
    final snapshot = await selected.readSnapshot(await selected.head());
    if (snapshot == null)
      throw StateError('The selected story is unavailable.');
    return decodeChronicle(snapshot);
  }

  String _file(String name) => directory.isEmpty ? name : '$directory/$name';
  List<String> get _branch => ['heads', ...branch.split('/')];

  @override
  Future<String> head() async {
    await _privateRepository();
    final ref = await _request('GET', ['git', 'ref', ..._branch]);
    return _sha((ref['object'] as _Json)['sha']);
  }

  Future<_Json> _privateRepository() async {
    final repo = await _request('GET', const []);
    if (repo['private'] != true) {
      throw StateError('Chronicle sync requires a private GitHub repository.');
    }
    return repo;
  }

  /// Lists complete stories directly under the configured catalog directory.
  Future<List<GitHubStory>> listStories({String catalog = 'stories'}) async {
    if (!_validParts(catalog.split('/'))) {
      throw ArgumentError('Invalid story catalog directory.');
    }
    final files = await _snapshotFiles(await head());
    final stories = <GitHubStory>[];
    final prefix = '$catalog/';
    for (final path in files.keys) {
      if (!path.startsWith(prefix)) continue;
      final relative = path.substring(prefix.length).split('/');
      if (relative.length != 2 || relative.last != 'manifest.json') continue;
      final name = relative.first;
      if (!_validParts([name])) continue;
      final directory = '$prefix$name';
      final snapshot = await _readSnapshot(files, directory);
      if (snapshot == null) continue;
      final chronicle = decodeChronicle(snapshot);
      stories.add((
        directory: directory,
        title: chronicle.adventures.values.firstOrNull?.title ?? name,
      ));
    }
    stories.sort((a, b) {
      final titleOrder = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return titleOrder == 0 ? a.directory.compareTo(b.directory) : titleOrder;
    });
    return List.unmodifiable(stories);
  }

  Future<Map<String, String>> _snapshotFiles(String commit) async {
    final treeSha = await _treeSha(commit);
    final tree = await _request(
      'GET',
      ['git', 'trees', treeSha],
      query: {'recursive': '1'},
    );
    if (tree['truncated'] != false) {
      throw const FormatException('GitHub tree could not be read completely.');
    }
    final files = <String, String>{};
    for (final entry in (tree['tree'] as List).cast<_Json>()) {
      final path = entry['path'] as String;
      final filename = path.split('/').last;
      if (filename == 'chronicle.json' || filename == 'manifest.json') {
        files[path] = entry['type'] == 'blob' && entry['mode'] == '100644'
            ? _sha(entry['sha'])
            : '';
      }
    }
    return files;
  }

  @override
  Future<String?> readSnapshot(String commit) async =>
      _readSnapshot(await _snapshotFiles(commit), directory);

  Future<String?> _readSnapshot(
    Map<String, String> files,
    String directory,
  ) async {
    final prefix = directory.isEmpty ? '' : '$directory/';
    final data = files['${prefix}chronicle.json'];
    final manifestSha = files['${prefix}manifest.json'];
    if (data == null && manifestSha == null) return null;
    if (data == null ||
        manifestSha == null ||
        data.isEmpty ||
        manifestSha.isEmpty) {
      throw const FormatException('Incomplete GitHub snapshot.');
    }
    final manifest = jsonDecode(await _readBlob(manifestSha)) as _Json;
    if (manifest['version'] != 1 || manifest['dataBlob'] != data) {
      throw const FormatException(
        'GitHub snapshot does not match its manifest.',
      );
    }
    return _readBlob(data);
  }

  @override
  Future<String> prepareCommit(String parent, String snapshot) async {
    final baseTree = await _treeSha(parent);
    final data = await _writeBlob(snapshot);
    final manifest = await _writeBlob(
      jsonEncode({'version': 1, 'dataBlob': data}),
    );
    final tree = await _request(
      'POST',
      ['git', 'trees'],
      body: {
        'base_tree': baseTree,
        'tree': [
          _entry('chronicle.json', data),
          _entry('manifest.json', manifest),
        ],
      },
    );
    final commit = await _request(
      'POST',
      ['git', 'commits'],
      body: {
        'message': 'Update Kronikas snapshot',
        'tree': _sha(tree['sha']),
        'parents': [_sha(parent)],
      },
    );
    return _sha(commit['sha']);
  }

  _Json _entry(String path, String sha) => {
    'path': _file(path),
    'mode': '100644',
    'type': 'blob',
    'sha': sha,
  };

  @override
  Future<bool> containsCommit(String head, String commit) async {
    if (head == commit) return true;
    final comparison = await _request('GET', [
      'compare',
      '${_sha(commit)}...${_sha(head)}',
    ]);
    return comparison['status'] == 'ahead' ||
        comparison['status'] == 'identical';
  }

  @override
  Future<void> advance(String commit) async {
    try {
      await _request(
        'PATCH',
        ['git', 'refs', ..._branch],
        body: {'sha': _sha(commit), 'force': false},
      );
    } on GitHubSyncException catch (error) {
      if (error.statusCode == 409 || error.statusCode == 422) {
        throw const RemoteWriteRejected();
      }
      rethrow;
    }
  }

  Future<String> _treeSha(String commit) async {
    final result = await _request('GET', ['git', 'commits', _sha(commit)]);
    return _sha((result['tree'] as _Json)['sha']);
  }

  Future<String> _readBlob(String sha) async {
    final result = await _request('GET', ['git', 'blobs', sha]);
    if (result['encoding'] != 'base64') {
      throw const FormatException('Unsupported GitHub blob encoding.');
    }
    return utf8.decode(
      base64.decode(
        (result['content'] as String).replaceAll(RegExp(r'\s'), ''),
      ),
    );
  }

  Future<String> _writeBlob(String content) async {
    final result = await _request(
      'POST',
      ['git', 'blobs'],
      body: {'content': content, 'encoding': 'utf-8'},
    );
    return _sha(result['sha']);
  }

  static String _sha(Object? value) {
    if (value is! String || !_shaPattern.hasMatch(value)) {
      throw const FormatException('Invalid GitHub object ID.');
    }
    return value;
  }

  Future<_Json> _request(
    String method,
    List<String> path, {
    _Json? body,
    Map<String, String>? query,
  }) async {
    final credential = await token();
    if (credential.isEmpty || credential.contains(RegExp(r'\s'))) {
      throw StateError('GitHub credentials are unavailable.');
    }
    final uri = Uri(
      scheme: 'https',
      host: 'api.github.com',
      pathSegments: ['repos', owner, repository, ...path],
      queryParameters: query,
    );
    final request = await client.openUrl(method, uri).timeout(_deadline);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $credential');
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(
      _deadline,
      onTimeout: () {
        request.abort();
        throw TimeoutException('GitHub sync request timed out.');
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>().timeout(_deadline);
      throw GitHubSyncException(response.statusCode);
    }
    return jsonDecode(
      await response.transform(utf8.decoder).join().timeout(_deadline),
    ) as _Json;
  }
}

({String owner, String repository}) parseGitHubRepository(String address) {
  final text = address.trim();
  final uri = Uri.tryParse(
    text.contains('://') ? text : 'https://github.com/$text',
  );
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'github.com' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException('Expected a GitHub repository address.');
  }
  final parts = uri.pathSegments;
  final normalized = parts.isNotEmpty && parts.last.isEmpty
      ? parts.take(parts.length - 1).toList()
      : parts;
  if (normalized.length != 2)
    throw const FormatException('Expected owner/repository.');
  final repository = normalized[1].endsWith('.git')
      ? normalized[1].substring(0, normalized[1].length - 4)
      : normalized[1];
  if (!GitHubChronicleRemote._repoName.hasMatch(normalized[0]) ||
      !GitHubChronicleRemote._repoName.hasMatch(repository)) {
    throw const FormatException('Invalid repository owner or name.');
  }
  return (owner: normalized[0], repository: repository);
}

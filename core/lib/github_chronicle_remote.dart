import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chronicle_sync.dart';

typedef _Json = Map<String, dynamic>;

final class GitHubSyncException implements Exception {
  const GitHubSyncException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'GitHub sync request failed (HTTP $statusCode).';
}

/// Stores one Chronicle document and its manifest on an existing private branch.
final class GitHubChronicleRemote implements ChronicleRemote {
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

  String _file(String name) => directory.isEmpty ? name : '$directory/$name';
  List<String> get _branch => ['heads', ...branch.split('/')];

  @override
  Future<String> head() async {
    final repo = await _request('GET', const []);
    if (repo['private'] != true) {
      throw StateError('Chronicle sync requires a private GitHub repository.');
    }
    final ref = await _request('GET', ['git', 'ref', ..._branch]);
    return _sha((ref['object'] as _Json)['sha']);
  }

  @override
  Future<String?> readSnapshot(String commit) async {
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
      final path = entry['path'];
      if (path == _file('chronicle.json') || path == _file('manifest.json')) {
        if (entry['type'] != 'blob' || entry['mode'] != '100644') {
          throw const FormatException('Unexpected GitHub snapshot entry.');
        }
        files[path as String] = _sha(entry['sha']);
      }
    }
    if (files.isEmpty) return null;
    final data = files[_file('chronicle.json')];
    final manifestSha = files[_file('manifest.json')];
    if (data == null || manifestSha == null) {
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

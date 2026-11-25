import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

typedef GitHubConnection = ({String token, List<String> repositories});

const _authEndpoint = String.fromEnvironment('KRONIKAS_AUTH_URL');

bool get githubSignInConfigured => _authEndpoint.isNotEmpty;

Future<void> _openBrowser(Uri url) async {
  if (url.scheme != 'https' ||
      url.host != 'github.com' ||
      url.userInfo.isNotEmpty) {
    throw StateError('Unexpected GitHub browser URL.');
  }
  if (Platform.isWindows) {
    final result = await Process.run('rundll32.exe', [
      'url.dll,FileProtocolHandler',
      url.toString(),
    ]);
    if (result.exitCode != 0) throw StateError('Could not open the browser.');
  } else {
    await const MethodChannel('hu.akihabarai.kronikas_platform_probe/storage')
        .invokeMethod<void>('openGitHubBrowser', url.toString());
  }
}

Future<GitHubConnection> connectGitHub() async {
  final endpoint = Uri.parse(_authEndpoint);
  if (endpoint.scheme != 'https' ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty) {
    throw StateError('An HTTPS GitHub login endpoint is required.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final (_, start) = await _request(
      client,
      endpoint.resolve('/github/start'),
      post: true,
    );
    final ticket = start['ticket'] as String;
    final authorize = Uri.parse(start['authorizeUrl'] as String);
    if (authorize.path != '/login/oauth/authorize') {
      throw StateError('Unexpected GitHub authorization URL.');
    }
    await _openBrowser(authorize);

    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < const Duration(minutes: 5)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final (status, result) = await _request(
        client,
        endpoint.resolve('/github/result'),
        post: true,
        token: ticket,
      );
      if (status == 202) continue;
      final token = result['token'];
      if (result['status'] != 'authorized' ||
          token is! String ||
          !token.startsWith('ghu_')) {
        throw StateError('GitHub login did not complete.');
      }
      return (token: token, repositories: await _repositories(client, token));
    }
    throw StateError('GitHub login expired.');
  } finally {
    client.close(force: true);
  }
}

Future<List<String>> refreshGitHubRepositories(String token) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    return await _repositories(client, token);
  } finally {
    client.close(force: true);
  }
}

Future<List<String>> _repositories(HttpClient client, String token) async {
  final repositories = <String>{};
  Future<void> paginate(
    String path,
    String key,
    void Function(Map<String, Object?>) read,
  ) async {
    for (var page = 1; ; page++) {
      final (_, body) = await _request(
        client,
        Uri.https('api.github.com', path, {'per_page': '100', 'page': '$page'}),
        token: token,
      );
      final values = body[key] as List<Object?>;
      values.cast<Map<String, Object?>>().forEach(read);
      if (values.length < 100) break;
    }
  }

  final installations = <int>[];
  await paginate(
    '/user/installations',
    'installations',
    (entry) => installations.add(entry['id'] as int),
  );
  for (final id in installations) {
    await paginate('/user/installations/$id/repositories', 'repositories', (
      entry,
    ) {
      if (entry['private'] == true)
        repositories.add(entry['full_name'] as String);
    });
  }
  return repositories.toList()..sort();
}

Future<(int, Map<String, Object?>)> _request(
  HttpClient client,
  Uri url, {
  bool post = false,
  String? token,
}) async {
  final request = await client.openUrl(post ? 'POST' : 'GET', url);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  request.headers.set(HttpHeaders.userAgentHeader, 'Kronikas');
  if (token != null)
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  final result = await request.close().timeout(const Duration(seconds: 20));
  final body = await utf8.decoder
      .bind(result)
      .join()
      .timeout(const Duration(seconds: 20));
  if (result.statusCode < 200 || result.statusCode >= 300) {
    throw StateError(
      'GitHub connection request failed (${result.statusCode}).',
    );
  }
  return (result.statusCode, jsonDecode(body) as Map<String, Object?>);
}

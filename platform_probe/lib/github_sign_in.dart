import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

typedef GitHubConnection = ({String token, List<String> repositories});

const _clientId = String.fromEnvironment('KRONIKAS_GITHUB_CLIENT_ID');

bool get githubSignInConfigured => _clientId.isNotEmpty;

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

typedef DevicePrompt = Future<bool> Function(
  String code,
  Future<void> Function() openGitHub,
);

Future<GitHubConnection?> connectGitHub(DevicePrompt prompt) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final (_, start) = await _request(
      client,
      Uri.https('github.com', '/login/device/code'),
      form: {'client_id': _clientId, 'scope': 'offline_access'},
    );
    final deviceCode = start['device_code'] as String;
    final userCode = start['user_code'] as String;
    final verification = Uri.parse(start['verification_uri'] as String);
    if (verification.path != '/login/device') {
      throw StateError('Unexpected GitHub device verification URL.');
    }
    var interval = Duration(seconds: start['interval'] as int);
    final expires = Duration(seconds: start['expires_in'] as int);
    if (interval <= Duration.zero || expires <= Duration.zero) {
      throw StateError('Invalid GitHub device authorization timing.');
    }
    final elapsed = Stopwatch()..start();
    if (!await prompt(userCode, () async {
      await Clipboard.setData(ClipboardData(text: userCode));
      await _openBrowser(verification);
    }))
      return null;

    while (elapsed.elapsed + interval < expires) {
      await Future<void>.delayed(interval);
      final (_, result) = await _request(
        client,
        Uri.https('github.com', '/login/oauth/access_token'),
        form: {
          'client_id': _clientId,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      final token = result['access_token'];
      if (token is String && token.startsWith('ghu_')) {
        return (token: token, repositories: await _repositories(client, token));
      }
      switch (result['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += const Duration(seconds: 5);
        default:
          throw StateError('GitHub login did not complete.');
      }
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
  Map<String, String>? form,
  String? token,
}) async {
  final request = await client.openUrl(form == null ? 'GET' : 'POST', url);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  request.headers.set(HttpHeaders.userAgentHeader, 'Kronikas');
  if (token != null)
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  if (form != null) {
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write(Uri(queryParameters: form).query);
  }
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

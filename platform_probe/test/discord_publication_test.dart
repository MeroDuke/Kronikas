import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_platform_probe/discord_publication.dart';

void main() {
  final webhook = parseDiscordWebhook(
    'https://discord.com/api/webhooks/123/synthetic',
  );
  final destination = (label: 'Teszt', webhook: webhook);

  test('restricts webhook URLs to Discord HTTPS', () {
    for (final url in [
      'http://discord.com/api/webhooks/123/synthetic',
      'https://discord.com.example/api/webhooks/123/synthetic',
      'https://user@discord.com/api/webhooks/123/synthetic',
      'https://discord.com/api/webhooks/123/synthetic?wait=false',
    ]) {
      expect(() => parseDiscordWebhook(url), throwsFormatException);
    }
  });

  test('sends one confirmed request without mentions or redirects', () async {
    final client = _Client(200, '{"id":"456"}');
    expect(
      await sendDiscordIntroduction(
        destination,
        'Próba @everyone',
        createClient: () => client,
      ),
      DiscordDelivery.sent,
    );
    expect(client.urls.single.queryParameters, {'wait': 'true'});
    expect(client.request.followRedirects, isFalse);
    expect(jsonDecode(client.request.body), {
      'content': 'Próba @everyone',
      'allowed_mentions': {'parse': <dynamic>[]},
    });
  });

  test('distinguishes failures and never retries ambiguous delivery', () async {
    for (final (status, body, expected) in [
      (404, '', DiscordDelivery.rejected),
      (429, '', DiscordDelivery.rateLimited),
      (500, '', DiscordDelivery.uncertain),
      (200, '{}', DiscordDelivery.uncertain),
      (null, '', DiscordDelivery.uncertain),
    ]) {
      final client = _Client(status, body);
      expect(
        await sendDiscordIntroduction(
          destination,
          'Próba',
          createClient: () => client,
        ),
        expected,
      );
      expect(client.urls, hasLength(1));
    }
  });
}

class _Client implements HttpClient {
  _Client(int? statusCode, String response)
    : request = _Request(statusCode, response);
  final _Request request;
  final urls = <Uri>[];

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    urls.add(url);
    return request;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.statusCode, this.response);
  final int? statusCode;
  final String response;
  late String body;

  @override
  bool followRedirects = true;

  @override
  final headers = _Headers();

  @override
  void write(Object? object) => body = object.toString();

  @override
  Future<HttpClientResponse> close() async {
    final status = statusCode;
    if (status == null) throw const SocketException('Lost response.');
    return _Response(status, response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  ContentType? contentType;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.body);
  @override
  final int statusCode;
  final String body;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(utf8.encode(body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

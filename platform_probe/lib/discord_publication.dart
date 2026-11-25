import 'dart:convert';
import 'dart:io';

typedef DiscordDestination = ({String label, Uri webhook});

enum DiscordDelivery { sent, rejected, rateLimited, uncertain }

const discordMessageLimit = 2000;

Uri parseDiscordWebhook(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'discord.com' ||
      uri.authority != 'discord.com' ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/api/(?:v10/)?webhooks/[0-9]+/[A-Za-z0-9_-]+$')
          .hasMatch(uri.path)) {
    throw const FormatException('Invalid Discord webhook.');
  }
  return uri;
}

Future<DiscordDelivery> sendDiscordIntroduction(
  DiscordDestination destination,
  String message, {
  HttpClient Function()? createClient,
}) async {
  final uri = parseDiscordWebhook(destination.webhook.toString());
  if (message.trim().isEmpty || message.length > discordMessageLimit) {
    throw const FormatException('Invalid Discord message length.');
  }
  final client = (createClient ?? HttpClient.new)();
  const timeout = Duration(seconds: 12);
  try {
    final request = await client
        .postUrl(uri.replace(queryParameters: {'wait': 'true'}))
        .timeout(timeout);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'content': message,
        'allowed_mentions': {'parse': <String>[]},
      }),
    );
    final response = await request.close().timeout(timeout);
    if (response.statusCode == 429) return DiscordDelivery.rateLimited;
    if (response.statusCode >= 400 && response.statusCode < 500) {
      return DiscordDelivery.rejected;
    }
    if (response.statusCode != 200) return DiscordDelivery.uncertain;
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    final receipt = jsonDecode(body);
    if (receipt is Map &&
        receipt['id'] is String &&
        (receipt['id'] as String).isNotEmpty) {
      return DiscordDelivery.sent;
    }
    return DiscordDelivery.uncertain;
  } on Exception {
    return DiscordDelivery.uncertain;
  } finally {
    client.close(force: true);
  }
}

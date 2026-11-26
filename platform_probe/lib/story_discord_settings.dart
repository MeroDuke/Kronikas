import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import 'discord_publication.dart';

const _channel = MethodChannel('hu.akihabarai.kronikas_platform_probe/storage');

final class StoryDiscordSettings {
  const StoryDiscordSettings(this.storyId, {this.storageRoot});

  final String storyId;
  final Directory? storageRoot;

  Future<File> _file() async {
    final path =
        storageRoot?.path ??
        (Platform.isWindows
            ? Platform.environment['LOCALAPPDATA']
            : await _channel.invokeMethod<String>('storagePath'));
    if (path == null) throw StateError('Storage unavailable.');
    final bytes = utf8.encode(storyId);
    final digest = (Sha256()..update(bytes, 0, bytes.length)).digest();
    final key = base64Url.encode(digest).replaceAll('=', '');
    return File.fromUri(
      Directory(path).absolute.uri.resolve('KronikasStories/discord/$key.bin'),
    );
  }

  Future<DiscordDestination?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final plain = await _channel.invokeMethod<Uint8List>(
      'unprotect',
      await file.readAsBytes(),
    );
    if (plain == null) throw const FormatException('Missing settings.');
    final stored = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return (
      label: stored['label'] as String,
      webhook: parseDiscordWebhook(stored['url'] as String),
    );
  }

  Future<void> save(DiscordDestination? destination) async {
    final file = await _file();
    if (destination == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    final protected = await _channel.invokeMethod<Uint8List>(
      'protect',
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'label': destination.label,
            'url': destination.webhook.toString(),
          }),
        ),
      ),
    );
    if (protected == null || protected.isEmpty) {
      throw StateError('Protected storage unavailable.');
    }
    await file.parent.create(recursive: true);
    final staging = await file.parent.createTemp('discord-');
    try {
      final temporary = File.fromUri(staging.uri.resolve('settings.bin'));
      await temporary.writeAsBytes(protected, flush: true);
      await temporary.rename(file.path);
    } finally {
      await staging.delete();
    }
  }
}

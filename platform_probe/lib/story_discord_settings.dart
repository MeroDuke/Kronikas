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

  Future<File> _file(String integration) async {
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
      Directory(path).absolute.uri
          .resolve('KronikasStories/$integration/$key.bin'),
    );
  }

  Future<String?> _read(String integration) async {
    final file = await _file(integration);
    if (!await file.exists()) return null;
    final plain = await _channel.invokeMethod<Uint8List>(
      'unprotect',
      await file.readAsBytes(),
    );
    if (plain == null) throw const FormatException('Missing settings.');
    return utf8.decode(plain);
  }

  Future<String?> loadOpenAiKey() => _read('openai');

  Future<void> saveOpenAiKey(String? key) {
    final value = key?.trim();
    if (value != null &&
        (value.isEmpty ||
            value.length > 1024 ||
            RegExp(r'\s').hasMatch(value))) {
      throw const FormatException('Invalid API key.');
    }
    return _write('openai', value);
  }

  Future<DiscordDestination?> load() async {
    final text = await _read('discord');
    if (text == null) return null;
    final stored = jsonDecode(text) as Map<String, dynamic>;
    return (
      label: stored['label'] as String,
      webhook: parseDiscordWebhook(stored['url'] as String),
    );
  }

  Future<void> save(DiscordDestination? destination) => _write(
    'discord',
    destination == null
        ? null
        : jsonEncode({
            'label': destination.label,
            'url': destination.webhook.toString(),
          }),
  );

  Future<void> _write(String integration, String? text) async {
    final file = await _file(integration);
    if (text == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    final protected = await _channel.invokeMethod<Uint8List>(
      'protect',
      Uint8List.fromList(utf8.encode(text)),
    );
    if (protected == null || protected.isEmpty) {
      throw StateError('Protected storage unavailable.');
    }
    await file.parent.create(recursive: true);
    final staging = await file.parent.createTemp('settings-');
    try {
      final temporary = File.fromUri(staging.uri.resolve('settings.bin'));
      await temporary.writeAsBytes(protected, flush: true);
      await temporary.rename(file.path);
    } finally {
      await staging.delete();
    }
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_platform_probe/story_discord_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps story destinations separate across reopen and removal', () async {
    const channel = MethodChannel(
      'hu.akihabarai.kronikas_platform_probe/storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.arguments;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final root = Directory.systemTemp.createTempSync('story-settings-');
    addTearDown(() => root.deleteSync(recursive: true));

    StoryDiscordSettings first() =>
        StoryDiscordSettings('first', storageRoot: root);
    final second = StoryDiscordSettings('second', storageRoot: root);
    final destination = (
      label: 'Teszt',
      webhook: Uri.parse('https://discord.com/api/webhooks/123/synthetic'),
    );
    expect(await first().load(), isNull);
    await first().save(destination);
    expect(await second.load(), isNull);
    expect(await first().load(), destination);
    final changed = (label: 'Másik csatorna', webhook: destination.webhook);
    await first().save(changed);
    expect(await first().load(), changed);
    await second.save(destination);
    await first().save(null);
    expect(await first().load(), isNull);
    expect(await second.load(), destination);
    expect(methods, [
      'protect',
      'unprotect',
      'protect',
      'unprotect',
      'protect',
      'unprotect',
    ]);
    expect(await first().loadOpenAiKey(), isNull);
    await first().saveOpenAiKey(' synthetic-key ');
    expect(await first().loadOpenAiKey(), 'synthetic-key');
    expect(await second.loadOpenAiKey(), isNull);
    expect(await second.load(), destination);
    await first().saveOpenAiKey('replacement-key');
    expect(await first().loadOpenAiKey(), 'replacement-key');
    await first().saveOpenAiKey(null);
    expect(await first().loadOpenAiKey(), isNull);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_platform_probe/debug_log.dart';

void main() {
  test('logging is opt-in, persists across startup and stops immediately', () {
    final root = Directory.systemTemp.createTempSync('kronikas-log-');
    addTearDown(() => root.deleteSync(recursive: true));
    final log = DebugLog(root);
    log.record(DebugEvent.discord_send_requested);
    expect(log.read(), isEmpty);
    log.setEnabled(true);
    log.record(DebugEvent.openai_key_saved);
    final enabled = DebugLog(root);
    expect(enabled.enabled, isTrue);
    expect(enabled.read(), contains('[settings] openai_key_saved'));
    final before = enabled.read();
    enabled.setEnabled(false);
    enabled.record(DebugEvent.field_edited);
    expect(DebugLog(root).enabled, isFalse);
    expect(enabled.read(), before);
  });

  test('rotates the current file and keeps one previous file', () {
    final root = Directory.systemTemp.createTempSync('kronikas-log-');
    addTearDown(() => root.deleteSync(recursive: true));
    final log = DebugLog(root, maxBytes: 128)..setEnabled(true);
    for (var i = 0; i < 20; i++) {
      log.record(DebugEvent.story_opened);
    }
    final files = root.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.log'),
    );
    expect(files, hasLength(2));
    expect(files.every((f) => f.lengthSync() <= 128), isTrue);
    expect(log.read(), contains('[document] story_opened'));
  });
}

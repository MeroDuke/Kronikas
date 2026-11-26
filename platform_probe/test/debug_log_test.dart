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

  test('preserves an existing logging preference with a new log directory', () {
    final root = Directory.systemTemp.createTempSync('kronikas-log-location-');
    addTearDown(() => root.deleteSync(recursive: true));
    final preferences = Directory.fromUri(root.uri.resolve('diagnostics/'));
    final previous = DebugLog(preferences)..setEnabled(true);
    final original = previous.read();
    final logs = Directory.fromUri(root.uri.resolve('logs/'));
    final marker = File.fromUri(preferences.uri.resolve('enabled'));
    final current = DebugLog(logs, enabledMarker: marker);
    expect(current.enabled, isTrue);
    current.record(DebugEvent.app_started);
    expect(current.read(), contains('app_started'));
    expect(previous.read(), original);
    current.setEnabled(false);
    expect(marker.existsSync(), isFalse);
  });

  test('prunes only expired application logs even when disabled', () {
    final root = Directory.systemTemp.createTempSync('kronikas-log-retention-');
    addTearDown(() => root.deleteSync(recursive: true));
    File write(String name) =>
        File.fromUri(root.uri.resolve(name))..writeAsStringSync('test');
    final now = DateTime.now().toUtc();
    final stamp = DebugLog.timestamp(now.subtract(const Duration(days: 15)));
    final expired = write('debug-$stamp.log');
    final unrelated = write('notes.log')
      ..setLastModifiedSync(now.subtract(const Duration(days: 20)));
    final recent = write('debug-${DebugLog.timestamp(now)}.log');
    final log = DebugLog(root);
    expect(log.enabled, isFalse);
    expect(expired.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
  });

  test('rotates without discarding recent files', () {
    final root = Directory.systemTemp.createTempSync('kronikas-log-');
    addTearDown(() => root.deleteSync(recursive: true));
    final log = DebugLog(root, maxBytes: 128)..setEnabled(true);
    for (var i = 0; i < 20; i++) {
      log.record(DebugEvent.story_opened);
    }
    final files = root.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.log'),
    );
    expect(files.length, greaterThan(2));
    expect(
      files.every(
        (file) =>
            RegExp(r'^debug-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}(?:-\d+)?\.log$')
                .hasMatch(file.uri.pathSegments.last),
      ),
      isTrue,
    );
    expect(files.every((f) => f.lengthSync() <= 128), isTrue);
    expect(log.read(), contains('[document] story_opened'));
  });
}

import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_core/story_storage_sync.dart';

import 'local_adventures.dart';
import 'story_storage_preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final path = Platform.isWindows
        ? Platform.environment['LOCALAPPDATA']
        : await const MethodChannel(
            'hu.akihabarai.kronikas_platform_probe/storage',
          ).invokeMethod<String>('storagePath');
    if (path == null) throw StateError('Storage unavailable.');
    final root = Directory(path).absolute.uri.resolve('KronikasStories/');
    final previewPath = Platform.environment['KRONIKAS_SYNC_PREVIEW_DIRECTORY'];
    final store = LocalChronicleStore(
      Directory.fromUri(
        root.resolve(previewPath == null ? 'local/' : 'storage-preview/'),
      ),
    );
    final sync = previewPath == null
        ? null
        : StoryStorageSync(
            store,
            StoryStoragePreview(Directory(previewPath).absolute),
          );
    runApp(
      MaterialApp(
        title: 'Krónikás',
        home: LocalAdventures(
          store: store,
          initial: store.open(),
          storyStorageSync: sync,
          standalone: true,
        ),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('A mesék tárolója nem nyitható meg.')),
        ),
      ),
    );
  }
}

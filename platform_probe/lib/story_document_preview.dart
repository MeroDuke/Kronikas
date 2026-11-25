import 'dart:io';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'story_document.dart';

const _channel = MethodChannel('hu.akihabarai.kronikas_platform_probe/storage');

class StoryDocumentPreview extends StatefulWidget {
  const StoryDocumentPreview({super.key});

  @override
  State<StoryDocumentPreview> createState() => _StoryDocumentPreviewState();
}

class _StoryDocumentPreviewState extends State<StoryDocumentPreview> {
  StoryDocument? _document;
  bool _busy = false;
  String? _error;

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String name;
      final Uint8List bytes;
      if (Platform.isWindows) {
        final path = await _channel.invokeMethod<String>('pickStoryDocument');
        if (path == null) return;
        final file = File(path);
        name = file.uri.pathSegments.last;
        final handle = await file.open();
        try {
          bytes = await handle.read(storyFileLimit + 1);
        } finally {
          await handle.close();
        }
      } else {
        final file = await _channel.invokeMapMethod<String, Object>(
          'pickStoryDocument',
        );
        if (file == null) return;
        name = file['name'] as String;
        bytes = file['bytes'] as Uint8List;
      }
      final document = await compute(
        (input) => readStoryDocument(input.$1, input.$2),
        (name, bytes),
      );
      if (mounted) setState(() => _document = document);
    } on NotStoryDocument {
      if (mounted) {
        setState(() {
          _document = null;
          _error = 'Ez a fájl nem Krónikás-mese.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'A dokumentum nem nyitható meg. Válassz egy Word-, TXT- vagy Markdown-fájlt, legfeljebb 8 MB méretben.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final styles = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mese előnézete')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              FilledButton(
                onPressed: _busy ? null : _open,
                child: Text(
                  document == null
                      ? 'Fájl kiválasztása'
                      : 'Másik fájl megnyitása',
                ),
              ),
              if (document == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Word (.docx), szöveg (.txt) vagy Markdown (.md)',
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?)
                Semantics(liveRegion: true, child: Text(error)),
              if (document != null) ...[
                const SizedBox(height: 24),
                Text(document.title, style: styles.headlineMedium),
                for (final section in document.sections)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: 16,
                      start: section.kind.depth * 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title.isEmpty
                              ? section.kind.label
                              : '${section.kind.label} – ${section.title}',
                          style: styles.titleMedium,
                        ),
                        for (final paragraph in section.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SelectableText(paragraph),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

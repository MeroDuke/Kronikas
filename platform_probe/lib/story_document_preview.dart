import 'dart:io';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'discord_publication.dart';
import 'discord_share.dart';
import 'story_discord_settings.dart';
import 'story_settings.dart';
import 'story_document.dart';

const _channel = MethodChannel('hu.akihabarai.kronikas_platform_probe/storage');

class StoryDocumentPreview extends StatefulWidget {
  const StoryDocumentPreview({super.key});

  @override
  State<StoryDocumentPreview> createState() => _StoryDocumentPreviewState();
}

class _StoryDocumentPreviewState extends State<StoryDocumentPreview> {
  StoryDocument? _document;
  StoryDiscordSettings? _settings;
  DiscordDestination? _destination;
  bool _settingsUnreadable = false;

  Future<void> _loadDestination(StoryDiscordSettings settings) async {
    DiscordDestination? destination;
    var unreadable = false;
    try {
      destination = await settings.load();
    } catch (_) {
      unreadable = true;
    }
    if (mounted && identical(settings, _settings)) {
      setState(() {
        _destination = destination;
        _settingsUnreadable = unreadable;
      });
    }
  }

  Future<void> _openSettings(StoryDiscordSettings settings) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => StorySettings(settings: settings)),
    );
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _loadDestination(settings);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _busy = false;
  String? _error;

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String name;
      final String storyId;
      final Uint8List bytes;
      if (Platform.isWindows) {
        final path = await _channel.invokeMethod<String>('pickStoryDocument');
        if (path == null) return;
        final file = File(path);
        name = file.uri.pathSegments.last;
        storyId = 'file:${(await file.resolveSymbolicLinks()).toLowerCase()}';
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
        storyId = 'document:${file['uri'] as String}';
        bytes = file['bytes'] as Uint8List;
      }
      final document = await compute(
        (input) => readStoryDocument(input.$1, input.$2),
        (name, bytes),
      );
      if (!mounted) return;
      final settings = StoryDiscordSettings(storyId);
      setState(() {
        _document = document;
        _settings = settings;
        _destination = null;
        _settingsUnreadable = false;
      });
      await _loadDestination(settings);
    } on NotStoryDocument {
      if (mounted) {
        setState(() {
          _document = null;
          _settings = null;
          _destination = null;
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
    final settings = _settings;
    final destination = _destination;
    final discordHelp = _settingsUnreadable
        ? 'A Discord-beállítás nem olvasható. Add meg újra a Beállításokban.'
        : 'A Discord-küldéshez állíts be webhookot a mese Beállítások menüjében.';
    final theme = Theme.of(context);
    final styles = theme.textTheme;
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mese előnézete'),
        actions: [
          if (settings != null)
            TextButton(
              onPressed: _busy ? null : () => _openSettings(settings),
              child: const Text('Beállítások'),
            ),
        ],
      ),
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        border: Border.all(color: colors.error),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DefaultTextStyle(
                          style: styles.bodyMedium!.copyWith(
                            color: colors.onErrorContainer,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Megnyitási hiba',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(error),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (document != null) ...[
                const SizedBox(height: 24),
                Text(document.title, style: styles.headlineMedium),
                for (final (kind, title) in const [
                  (
                    StorySectionKind.introduction,
                    'Bevezető megosztása Discordon',
                  ),
                  (StorySectionKind.summary, 'Összegzés megosztása Discordon'),
                ])
                  if (storySectionMessage(document, kind) case final message?)
                    Tooltip(
                      message: destination == null && !_busy ? discordHelp : '',
                      child: OutlinedButton(
                        onPressed: _busy || destination == null
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => DiscordShare(
                                    title: title,
                                    message: message,
                                    destination: destination,
                                  ),
                                ),
                              ),
                        child: Text(title),
                      ),
                    ),
                if (destination == null &&
                    !_busy &&
                    (storySectionMessage(
                              document,
                              StorySectionKind.introduction,
                            ) !=
                            null ||
                        storySectionMessage(
                              document,
                              StorySectionKind.summary,
                            ) !=
                            null))
                  Text(discordHelp, style: styles.bodySmall),
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

import 'dart:convert';
import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'discord_publication.dart';

const _channel = MethodChannel('hu.akihabarai.kronikas_platform_probe/storage');

class DiscordIntroduction extends StatefulWidget {
  const DiscordIntroduction({super.key, required this.message});

  final String message;

  @override
  State<DiscordIntroduction> createState() => _DiscordIntroductionState();
}

class _DiscordIntroductionState extends State<DiscordIntroduction> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _webhook = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _status;
  DiscordDelivery? _delivery;
  DiscordDestination? _destination;

  @override
  void initState() {
    super.initState();
    _loadDestination();
  }

  @override
  void dispose() {
    _label.dispose();
    _webhook.dispose();
    super.dispose();
  }

  Future<File> _settingsFile() async {
    final path = Platform.isWindows
        ? Platform.environment['LOCALAPPDATA']
        : await _channel.invokeMethod<String>('storagePath');
    if (path == null) throw StateError('Storage unavailable.');
    return File.fromUri(
      Directory(path).absolute.uri.resolve('KronikasStories/discord.bin'),
    );
  }

  Future<void> _loadDestination() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return;
      final plain = await _channel.invokeMethod<Uint8List>(
        'unprotect',
        await file.readAsBytes(),
      );
      if (plain == null) throw const FormatException('Missing settings.');
      final stored = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      if (!mounted) return;
      _label.text = stored['label'] as String;
      _webhook.text = parseDiscordWebhook(stored['url'] as String).toString();
    } catch (_) {
      if (mounted) _status = 'A mentett Discord-beállítás nem olvasható.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preview() async {
    if (!_form.currentState!.validate()) return;
    final destination = (
      label: _label.text.trim(),
      webhook: parseDiscordWebhook(_webhook.text),
    );
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final file = await _settingsFile();
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
      if (mounted) setState(() => _destination = destination);
    } catch (_) {
      if (mounted)
        setState(() => _status = 'A Discord-beállítás mentése sikertelen.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final destination = _destination!;
    setState(() {
      _sending = true;
      _status = null;
    });
    final result = await sendDiscordIntroduction(destination, widget.message);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _delivery = result;
      _status = switch (result) {
        DiscordDelivery.sent => 'A bevezető megjelent a Discordon.',
        DiscordDelivery.rejected =>
          'A Discord elutasította a küldést. Ellenőrizd a webhook linkjét.',
        DiscordDelivery.rateLimited =>
          'A Discord átmenetileg korlátozza a küldést. Próbáld meg később.',
        DiscordDelivery.uncertain => 'A küldés eredménye bizonytalan. Nézd meg a Discord-csatornát, mielőtt újra küldöd.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    final tooLong = widget.message.length > discordMessageLimit;
    return Scaffold(
      appBar: AppBar(title: const Text('Bevezető megosztása')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_loading || _sending) const LinearProgressIndicator(),
              if (destination == null)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _label,
                        enabled: !_loading,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Csatorna neve',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Add meg a csatorna nevét.'
                            : null,
                      ),
                      TextFormField(
                        controller: _webhook,
                        enabled: !_loading,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Discord webhook link',
                        ),
                        validator: (value) {
                          try {
                            parseDiscordWebhook(value ?? '');
                            return null;
                          } on FormatException {
                            return 'Adj meg egy érvényes Discord webhook linket.';
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _preview,
                        child: const Text('Küldés előnézete'),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SelectableText(widget.message),
                const SizedBox(height: 12),
                if (tooLong)
                  const Text(
                    'A bevezető túllépi a Discord 2000 karakteres üzenethatárát.',
                  ),
                FilledButton(
                  onPressed:
                      _sending ||
                          tooLong ||
                          _delivery == DiscordDelivery.sent ||
                          _delivery == DiscordDelivery.uncertain
                      ? null
                      : _send,
                  child: const Text('Küldés Discordra'),
                ),
                TextButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                          _destination = null;
                          _status = null;
                        }),
                  child: const Text('Discord-beállítások'),
                ),
              ],
              if (_status case final status?)
                Semantics(liveRegion: true, child: Text(status)),
            ],
          ),
        ),
      ),
    );
  }
}

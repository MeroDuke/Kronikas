// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'discord_publication.dart';
import 'openai_summary.dart';
import 'story_discord_settings.dart';

class DiscordShare extends StatefulWidget {
  const DiscordShare({
    super.key,
    required this.message,
    required this.title,
    required this.destination,
    this.storyContext,
    this.settings,
  });

  final String message;
  final String title;
  final DiscordDestination destination;
  final String? storyContext;
  final StoryDiscordSettings? settings;

  @override
  State<DiscordShare> createState() => _DiscordShareState();
}

class _DiscordShareState extends State<DiscordShare> {
  bool _sending = false;
  bool _useAi = false;
  String? _generated;
  String? _status;
  DiscordDelivery? _delivery;

  Future<void> _send() async {
    final destination = widget.destination;
    setState(() {
      _sending = true;
      _status = null;
    });
    var message = widget.message;
    if (_useAi) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fizetős OpenAI-generálás'),
          content: Text(
            'Az OpenAI API használata fizetős. A díjat az OpenAI számolja fel az API-fiókodban. A funkcióhoz aktív, számlázásra vagy kreditre jogosult API-hozzáférés kell. A mese teljes beolvasott szövege, a mesélői jegyzetekkel együtt, az OpenAI-hoz kerül. Az elkészült összegzést a Krónikás elküldi ide: ${destination.label}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Elutasítom'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elfogadom és küldöm'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (approved != true) {
        setState(() => _sending = false);
        return;
      }
      try {
        final key = await widget.settings!.loadOpenAiKey();
        if (key == null) {
          throw const OpenAiSummaryException(
            'Add meg az OpenAI API-kulcsot a mese Beállításaiban.',
          );
        }
        message = await generateOpenAiSummary(key, widget.storyContext!);
        if (!mounted) return;
        setState(() => _generated = message);
        if (message.length > discordMessageLimit) {
          throw const OpenAiSummaryException(
            'A generált összegzés túllépi a Discord üzenethatárát.',
          );
        }
      } catch (error) {
        if (mounted)
          setState(() {
            _sending = false;
            _status = error is OpenAiSummaryException
                ? error.message
                : 'Az OpenAI használata sikertelen.';
          });
        return;
      }
    }
    final result = await sendDiscordMessage(destination, message);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _delivery = result;
      _status = switch (result) {
        DiscordDelivery.sent => 'Az üzenet megjelent a Discordon.',
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
    final destination = widget.destination;
    final finished =
        _delivery == DiscordDelivery.sent ||
        _delivery == DiscordDelivery.uncertain;
    final tooLong = widget.message.length > discordMessageLimit;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_sending) const LinearProgressIndicator(),
              Text(
                destination.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (widget.storyContext != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useAi,
                  onChanged: _sending || finished || widget.settings == null
                      ? null
                      : (value) => setState(() {
                          _useAi = value ?? false;
                          _generated = null;
                          _status = null;
                        }),
                  title: const Text('Összegzés publikálása AI-támogatással'),
                  subtitle: widget.settings == null
                      ? const Text(
                          'Állíts be OpenAI API-kulcsot a mese Beállításaiban.',
                        )
                      : null,
                ),
              if ((_generated ?? widget.message).isNotEmpty)
                SelectableText(_generated ?? widget.message),
              const SizedBox(height: 12),
              if (!_useAi && tooLong)
                const Text(
                  'Az üzenet túllépi a Discord 2000 karakteres üzenethatárát.',
                ),
              FilledButton(
                onPressed:
                    _sending ||
                        (!_useAi && (tooLong || widget.message.isEmpty)) ||
                        _delivery == DiscordDelivery.sent ||
                        _delivery == DiscordDelivery.uncertain
                    ? null
                    : _send,
                child: const Text('Küldés Discordra'),
              ),
              if (_status case final status?)
                Semantics(liveRegion: true, child: Text(status)),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'discord_publication.dart';

class DiscordShare extends StatefulWidget {
  const DiscordShare({
    super.key,
    required this.message,
    required this.title,
    required this.destination,
  });

  final String message;
  final String title;
  final DiscordDestination destination;

  @override
  State<DiscordShare> createState() => _DiscordShareState();
}

class _DiscordShareState extends State<DiscordShare> {
  bool _sending = false;
  String? _status;
  DiscordDelivery? _delivery;

  Future<void> _send() async {
    final destination = widget.destination;
    setState(() {
      _sending = true;
      _status = null;
    });
    final result = await sendDiscordMessage(destination, widget.message);
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
              SelectableText(widget.message),
              const SizedBox(height: 12),
              if (tooLong)
                const Text(
                  'Az üzenet túllépi a Discord 2000 karakteres üzenethatárát.',
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
              if (_status case final status?)
                Semantics(liveRegion: true, child: Text(status)),
            ],
          ),
        ),
      ),
    );
  }
}

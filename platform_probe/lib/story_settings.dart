// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'discord_publication.dart';
import 'story_discord_settings.dart';

class StorySettings extends StatefulWidget {
  const StorySettings({super.key, required this.settings});

  final StoryDiscordSettings settings;

  @override
  State<StorySettings> createState() => _StorySettingsState();
}

class _StorySettingsState extends State<StorySettings> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _webhook = TextEditingController();
  bool _busy = true;
  bool _configured = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _label.dispose();
    _webhook.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final destination = await widget.settings.load();
      if (!mounted || destination == null) return;
      _configured = true;
      _label.text = destination.label;
      _webhook.text = destination.webhook.toString();
    } catch (_) {
      _error = 'A mentett Discord-beállítás nem olvasható.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool remove = false}) async {
    if (!remove && !_form.currentState!.validate()) return;
    final destination = remove
        ? null
        : (
            label: _label.text.trim(),
            webhook: parseDiscordWebhook(_webhook.text),
          );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.settings.save(destination);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        setState(() => _error = 'A Discord-beállítás mentése sikertelen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beállítások')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Discord', style: Theme.of(context).textTheme.titleLarge),
              TextFormField(
                controller: _label,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Csatorna neve'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add meg a csatorna nevét.'
                    : null,
              ),
              TextFormField(
                controller: _webhook,
                enabled: !_busy,
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
                onPressed: _busy ? null : () => _save(),
                child: const Text('Mentés'),
              ),
              if (_configured)
                TextButton(
                  onPressed: _busy ? null : () => _save(remove: true),
                  child: const Text('Discord leválasztása'),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?)
                Semantics(liveRegion: true, child: Text(error)),
            ],
          ),
        ),
      ),
    ),
  );
}

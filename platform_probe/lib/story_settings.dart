// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'discord_publication.dart';
import 'debug_log.dart';
import 'debug_log_settings.dart';
import 'story_discord_settings.dart';

class StorySettings extends StatefulWidget {
  const StorySettings({super.key, this.settings});

  final StoryDiscordSettings? settings;

  @override
  State<StorySettings> createState() => _StorySettingsState();
}

class _StorySettingsState extends State<StorySettings> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _webhook = TextEditingController();
  final _openAiKey = TextEditingController();
  bool _openAiBusy = true;
  bool _openAiConfigured = false;
  String? _openAiStatus;
  bool _busy = true;
  bool _configured = false;
  String? _discordStatus;

  @override
  void initState() {
    super.initState();
    if (widget.settings != null) {
      _load();
      _loadOpenAi();
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _webhook.dispose();
    _openAiKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final destination = await widget.settings!.load();
      if (!mounted || destination == null) return;
      _configured = true;
      _label.text = destination.label;
      _webhook.text = destination.webhook.toString();
    } catch (_) {
      _discordStatus = 'A mentett Discord-beállítás nem olvasható.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadOpenAi() async {
    try {
      final key = await widget.settings!.loadOpenAiKey();
      if (mounted) _openAiConfigured = key != null;
    } catch (_) {
      if (mounted)
        _openAiStatus = 'A mentett API-kulcs nem olvasható. Add meg újra.';
    } finally {
      if (mounted) setState(() => _openAiBusy = false);
    }
  }

  Future<void> _saveOpenAi({bool remove = false}) async {
    debugEvent(
      remove
          ? DebugEvent.openai_key_remove_requested
          : DebugEvent.openai_key_save_requested,
    );
    setState(() {
      _openAiBusy = true;
      _openAiStatus = null;
    });
    try {
      final key = remove ? null : _openAiKey.text.trim();
      await widget.settings!.saveOpenAiKey(key);
      if (await widget.settings!.loadOpenAiKey() != key) {
        throw StateError('OpenAI settings could not be read back.');
      }
      if (!mounted) return;
      debugEvent(
        remove ? DebugEvent.openai_key_removed : DebugEvent.openai_key_saved,
      );
      _openAiKey.clear();
      _openAiConfigured = !remove;
      _openAiStatus = remove ? 'Az API-kulcs törölve.' : 'Az API-kulcs mentve.';
    } on FormatException {
      debugEvent(DebugEvent.openai_key_failed);
      _openAiStatus = 'Adj meg egy API-kulcsot szóközök nélkül.';
    } catch (_) {
      debugEvent(DebugEvent.openai_key_failed);
      _openAiStatus = 'Az API-kulcs mentése sikertelen.';
    } finally {
      if (mounted) setState(() => _openAiBusy = false);
    }
  }

  Future<void> _save({bool remove = false}) async {
    debugEvent(
      remove
          ? DebugEvent.discord_settings_remove_requested
          : DebugEvent.discord_settings_save_requested,
    );
    if (!remove && !_form.currentState!.validate()) return;
    final destination = remove
        ? null
        : (
            label: _label.text.trim(),
            webhook: parseDiscordWebhook(_webhook.text),
          );
    setState(() {
      _busy = true;
      _discordStatus = null;
    });
    try {
      await widget.settings!.save(destination);
      if (await widget.settings!.load() != destination) {
        throw StateError('Discord settings could not be read back.');
      }
      if (!mounted) return;
      debugEvent(
        remove
            ? DebugEvent.discord_settings_removed
            : DebugEvent.discord_settings_saved,
      );
      _configured = !remove;
      if (remove) {
        _label.clear();
        _webhook.clear();
      }
      _discordStatus = remove
          ? 'A Discord leválasztva.'
          : 'A Discord-beállítás mentve.';
    } catch (_) {
      if (mounted)
        setState(
          () => _discordStatus = 'A Discord-beállítás mentése sikertelen.',
        );
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
              if (widget.settings != null) ...[
                Text('Discord', style: Theme.of(context).textTheme.titleLarge),
                TextFormField(
                  controller: _label,
                  onChanged: (_) => debugEvent(DebugEvent.field_edited),
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
                  child: const Text('Discord mentése'),
                ),
                if (_configured)
                  TextButton(
                    onPressed: _busy ? null : () => _save(remove: true),
                    child: const Text('Discord leválasztása'),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if ((_discordStatus ??
                        (_configured ? 'Van mentett Discord-cél.' : null))
                    case final status?)
                  Semantics(liveRegion: true, child: Text(status)),
                const SizedBox(height: 24),
                Text('OpenAI', style: Theme.of(context).textTheme.titleLarge),
                TextField(
                  controller: _openAiKey,
                  enabled: !_openAiBusy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: _openAiConfigured
                        ? 'Új OpenAI API-kulcs'
                        : 'OpenAI API-kulcs',
                    helperText: _openAiConfigured
                        ? 'Van mentett API-kulcs.'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _openAiBusy ? null : () => _saveOpenAi(),
                  child: const Text('API-kulcs mentése'),
                ),
                if (_openAiConfigured)
                  TextButton(
                    onPressed: _openAiBusy
                        ? null
                        : () => _saveOpenAi(remove: true),
                    child: const Text('API-kulcs törlése'),
                  ),
                if (_openAiStatus case final status?)
                  Semantics(liveRegion: true, child: Text(status)),
                if (_openAiBusy) const LinearProgressIndicator(),
                const SizedBox(height: 24),
              ],
              const DebugLogSettings(),
            ],
          ),
        ),
      ),
    ),
  );
}

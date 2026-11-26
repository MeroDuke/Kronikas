import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug_log.dart';

class DebugLogSettings extends StatefulWidget {
  const DebugLogSettings({super.key});

  @override
  State<DebugLogSettings> createState() => _DebugLogSettingsState();
}

class _DebugLogSettingsState extends State<DebugLogSettings> {
  String? _status;

  void _toggle(DebugLog log, bool enabled) {
    try {
      log.setEnabled(enabled);
      setState(() => _status = null);
    } on FileSystemException {
      setState(() => _status = 'A naplózási beállítás mentése sikertelen.');
    }
  }

  Future<void> _copy(DebugLog log) async {
    try {
      final content = log.read();
      if (content.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: content));
        debugEvent(DebugEvent.log_copied);
      }
      if (mounted)
        setState(
          () => _status = content.isEmpty
              ? 'Még nincs naplóbejegyzés.'
              : 'A napló a vágólapra került.',
        );
    } catch (_) {
      if (mounted) setState(() => _status = 'A napló másolása sikertelen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = DebugLog.current;
    if (log == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hibakeresési napló'),
          value: log.enabled,
          onChanged: (enabled) => _toggle(log, enabled),
        ),
        OutlinedButton(
          onPressed: () => _copy(log),
          child: const Text('Napló másolása'),
        ),
        if (_status case final status?)
          Semantics(liveRegion: true, child: Text(status)),
      ],
    );
  }
}

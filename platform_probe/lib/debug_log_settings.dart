import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug_log.dart';

const _storage = MethodChannel('hu.akihabarai.kronikas_platform_probe/storage');

class DebugLogSettings extends StatefulWidget {
  const DebugLogSettings({super.key});

  @override
  State<DebugLogSettings> createState() => _DebugLogSettingsState();
}

class _DebugLogSettingsState extends State<DebugLogSettings> {
  String? _status;
  bool _saving = false;

  void _toggle(DebugLog log, bool enabled) {
    try {
      log.setEnabled(enabled);
      setState(() => _status = null);
    } on FileSystemException {
      setState(() => _status = 'A naplózási beállítás mentése sikertelen.');
    }
  }

  Future<void> _openFolder(DebugLog log) async {
    try {
      log.pruneExpired();
      await log.directory.create(recursive: true);
      await Process.start('explorer.exe', [log.directory.path]);
    } catch (_) {
      if (mounted)
        setState(() => _status = 'A naplómappa megnyitása sikertelen.');
    }
  }

  Future<void> _export(DebugLog log) async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final files = log.filesForExport();
      if (files.isEmpty) {
        if (mounted) setState(() => _status = 'Még nincs naplóbejegyzés.');
        return;
      }
      final selected = await showDialog<File>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Melyik naplót mented?'),
          children: [
            for (final file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, file),
                child: Text(file.uri.pathSegments.last),
              ),
          ],
        ),
      );
      if (!mounted || selected == null) return;
      final filename = await _storage.invokeMethod<String>('saveDebugLog', {
        'name': selected.uri.pathSegments.last,
        'bytes': await selected.readAsBytes(),
      });
      if (filename != null) {
        debugEvent(DebugEvent.log_exported);
        if (mounted)
          setState(
            () => _status = 'A napló mentve a kiválasztott mappába. $filename',
          );
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'A naplófájl mentése sikertelen.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
        if (Platform.isWindows) ...[
          const Text('Mentési mappa'),
          SelectableText(log.directory.path),
          const Text('Példa: debug-2026-11-26_14-32-08.log (UTC)'),
          OutlinedButton(
            onPressed: () => _openFolder(log),
            child: const Text('Naplómappa megnyitása'),
          ),
        ] else if (Platform.isAndroid) ...[
          const Text(
            'A napló az alkalmazás tárhelyén gyűlik. A Fájlok alkalmazásból elérhető másolathoz válassz mentési mappát.',
          ),
          OutlinedButton(
            onPressed: _saving ? null : () => _export(log),
            child: const Text('Naplófájl mentése'),
          ),
        ],
        if ((_status ??
                (log.writeFailed
                    ? 'A naplófájl nem írható a megadott mappába.'
                    : null))
            case final status?)
          Semantics(liveRegion: true, child: Text(status)),
      ],
    );
  }
}

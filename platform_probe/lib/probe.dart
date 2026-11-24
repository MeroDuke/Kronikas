import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

const _channel = MethodChannel('hu.akihabarai.kronikas_platform_probe/storage');
const _sample = 'synthetic-kronikas-probe-value-v1';

void runProbe() {
  runApp(
    WidgetsApp(
      color: const Color(0xfff4f5f7),
      builder: (_, _) => const DefaultTextStyle(
        style: TextStyle(color: Color(0xff16283e), fontSize: 18),
        child: _Probe(),
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String _status = 'Ready for synthetic probe.';
  bool _busy = false;

  Future<void> _run(Future<String> Function(Directory) operation) async {
    setState(() => _busy = true);
    try {
      final path = Platform.isWindows
          ? Platform.environment['KRONIKAS_PROBE_HOME'] ??
                '${Platform.environment['LOCALAPPDATA']}\\KronikasPlatformProbe'
          : await _channel.invokeMethod<String>('storagePath');
      if (path == null) throw StateError('Application directory unavailable.');
      final directory = Directory(path).absolute;
      await directory.create(recursive: true);
      final result = await operation(directory);
      if (mounted) setState(() => _status = result);
    } catch (_) {
      if (mounted) setState(() => _status = 'Probe failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  LocalChronicleStore _store(Directory root) =>
      LocalChronicleStore(Directory.fromUri(root.uri.resolve('chronicle/')));

  Future<String> _write(Directory root) async {
    final bytes = Uint8List.fromList(utf8.encode(_sample));
    final protected = await _channel.invokeMethod<Uint8List>('protect', bytes);
    if (protected == null || protected.isEmpty) throw StateError('No payload.');
    await File.fromUri(root.uri.resolve('probe-secret.bin'))
        .writeAsBytes(protected, flush: true);
    _store(root).update((chronicle) {
      if (chronicle.adventures.containsKey('probe')) return;
      chronicle.createAdventure(id: 'probe', title: 'Synthetic river');
      chronicle.addMilestone('probe', id: 'cross', title: 'Cross the river');
      chronicle.startSession(
        'probe',
        id: 'test',
        startedAt: DateTime.utc(2026),
      );
      chronicle.recordMilestoneOutcome(
        'probe',
        'test',
        eventId: 'crossed',
        milestoneId: 'cross',
        status: MilestoneStatus.completed,
        outcome: 'Crossed the river.',
      );
    });
    return 'Synthetic chronicle and protected value saved.';
  }

  Future<String> _read(Directory root) async {
    final protected = await File.fromUri(root.uri.resolve('probe-secret.bin'))
        .readAsBytes();
    final value = await _channel.invokeMethod<Uint8List>(
      'unprotect',
      protected,
    );
    final chronicle = _store(root).open().adventures['probe'];
    final progress = chronicle?.progress['cross'];
    final events = chronicle?.sessions['test']?.events;
    if (value == null ||
        utf8.decode(value) != _sample ||
        utf8.decode(protected, allowMalformed: true).contains(_sample) ||
        progress?.status != MilestoneStatus.completed ||
        events?.length != 1 ||
        events?.single.id != progress?.eventId) {
      throw StateError('Probe did not round-trip.');
    }
    return 'Chronicle and protected value verified.';
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xfff4f5f7),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Kronikas Platform Probe',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              _button('Save test data', _busy ? null : () => _run(_write)),
              const SizedBox(height: 12),
              _button('Verify saved data', _busy ? null : () => _run(_read)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _button(String label, VoidCallback? action) => Semantics(
    button: true,
    enabled: action != null,
    child: GestureDetector(
      onTap: action,
      child: ColoredBox(
        color: const Color(0xffd6e4f4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

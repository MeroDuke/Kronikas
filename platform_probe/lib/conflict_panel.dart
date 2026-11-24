import 'dart:convert';

// Use the pinned SDK without an additional dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:kronikas_core/chronicle_sync.dart';

class ConflictPanel extends StatefulWidget {
  const ConflictPanel({
    super.key,
    required this.sync,
    required this.onChanged,
    this.testRemoteEdit,
  });

  final ChronicleSync sync;
  final VoidCallback onChanged;
  final Future<void> Function()? testRemoteEdit;

  @override
  State<ConflictPanel> createState() => _ConflictPanelState();
}

class _ConflictPanelState extends State<ConflictPanel> {
  SyncConflictReview? _review;
  final _choices = <String, String?>{};
  String? _status;
  String? _backup;
  bool _busy = false;

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _status = null;
      _backup = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) setState(() => _status = 'A szinkronművelet sikertelen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewCurrent(String status) async {
    final review = await widget.sync.reviewConflict();
    if (!mounted) return;
    setState(() {
      _review = review;
      _choices.clear();
      _status = status;
    });
  }

  Future<void> _synchronize() => _run(() async {
    final result = await widget.sync.synchronize();
    if (!mounted) return;
    if (result == SyncOutcome.conflict || result == SyncOutcome.localChanged) {
      await _reviewCurrent('A két változat eltér.');
    } else {
      setState(() {
        _review = null;
        _status = 'Szinkronizálva.';
      });
      widget.onChanged();
    }
  });

  Future<void> _resolve(SyncConflictReview review, {bool? useLocal}) =>
      _run(() async {
        final result = await widget.sync.resolveConflict(
          review,
          selections: useLocal == null
              ? [for (final field in review.conflicts) _choices[_key(field)]]
              : const [],
          snapshot: switch (useLocal) {
            true => review.localVersion,
            false => review.remoteVersion,
            null => null,
          },
        );
        if (!mounted) return;
        if (result != SyncOutcome.uploaded) {
          await _reviewCurrent('A változatok frissültek. Erősítsd meg újra.');
          return;
        }
        setState(() {
          _review = null;
          _status = 'A feloldás mentve.';
        });
        widget.onChanged();
      });

  String _key(MergeConflict field) => jsonEncode(field.path);

  String _display(String? value) {
    if (value == null) return 'Hiányzik';
    final decoded = jsonDecode(value);
    return decoded is String ? decoded : value;
  }

  Future<void> _showBackup(SyncResolutionBackup backup, bool remote) =>
      _run(() async {
        final original = await widget.sync.restoreResolutionBackup(
          backup,
          fromRemote: remote,
        );
        if (!mounted) return;
        final titles = original?.adventures.values.map((item) => item.title);
        setState(() => _backup = titles?.join(', ') ?? 'Üres változat');
      });

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final backups = widget.sync.listResolutionBackups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: _busy ? null : _synchronize,
          child: const Text('Mese szinkronizálása'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_status case final String status)
          Semantics(liveRegion: true, child: Text(status)),
        if (review != null) ...[
          if (widget.testRemoteEdit case final edit?)
            TextButton(
              onPressed: _busy ? null : () => _run(edit),
              child: const Text('Szimulált távoli módosítás'),
            ),
          Text(
            'Szinkronütközés',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (review.requiresSnapshot) ...[
            Text(
              'Helyi: ${review.localVersion.adventures.values.map((item) => item.title).join(', ')}',
            ),
            Text(
              'Távoli: ${review.remoteVersion?.adventures.values.map((item) => item.title).join(', ') ?? 'Üres változat'}',
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _resolve(review, useLocal: true),
              child: const Text('Teljes helyi változat használata'),
            ),
            if (review.remoteVersion != null)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _resolve(review, useLocal: false),
                child: const Text('Teljes távoli változat használata'),
              ),
          ] else ...[
            for (final field in review.conflicts)
              Padding(
                key: ValueKey((review, _key(field))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(field.path.join(' / ')),
                    Text('Helyi: ${_display(field.local)}'),
                    Text('Távoli: ${_display(field.remote)}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _choices[_key(field)] = field.local,
                                ),
                          child: const Text('Helyi érték'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _choices[_key(field)] = field.remote,
                                ),
                          child: const Text('Távoli érték'),
                        ),
                      ],
                    ),
                    if ([field.local, field.remote].whereType<String>().every(
                      (value) => jsonDecode(value) is String,
                    ))
                      TextField(
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Új érték',
                        ),
                        onChanged: (value) => setState(
                          () => _choices[_key(field)] = jsonEncode(value),
                        ),
                      ),
                    if (_choices.containsKey(_key(field)))
                      Text('Kiválasztva: ${_display(_choices[_key(field)])}'),
                  ],
                ),
              ),
            FilledButton(
              onPressed:
                  !_busy &&
                      review.conflicts.isNotEmpty &&
                      _choices.length == review.conflicts.length
                  ? () => _resolve(review)
                  : null,
              child: const Text('Feloldás mentése'),
            ),
          ],
        ],
        for (final (index, backup) in backups.indexed) ...[
          Text('Feloldás előtti változatok · ${index + 1}'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _showBackup(backup, false),
                child: const Text('Eredeti helyi változat megnyitása'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _showBackup(backup, true),
                child: const Text('Eredeti távoli változat megnyitása'),
              ),
            ],
          ),
        ],
        if (_backup case final String backup)
          Text('Visszaállított példány: $backup'),
      ],
    );
  }
}

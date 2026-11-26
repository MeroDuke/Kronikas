import 'dart:async';
import 'dart:math';

import 'debug_log.dart';
import 'story_document_preview.dart';
import 'story_discord_settings.dart';
import 'story_settings.dart';

// Use the Material widgets from the pinned Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_core/story_storage_sync.dart';

class LocalAdventures extends StatefulWidget {
  const LocalAdventures({
    super.key,
    required this.store,
    required this.initial,
    this.storyStorageSync,
    this.standalone = false,
  });

  final LocalChronicleStore store;
  final Chronicle initial;
  final StoryStorageSync? storyStorageSync;
  final bool standalone;

  @override
  State<LocalAdventures> createState() => _LocalAdventuresState();
}

class _LocalAdventuresState extends State<LocalAdventures> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late Chronicle _chronicle = widget.initial;
  String? _selected;
  String? _error;
  bool _creating = false;
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_sync(download: true));
  }

  Future<void> _sync({bool download = false}) async {
    final sync = widget.storyStorageSync;
    if (sync == null) return;
    debugEvent(DebugEvent.sync_started);
    final result = await sync.synchronize(download: download);
    debugEvent(switch (result) {
      StorySyncResult.complete => DebugEvent.sync_completed,
      StorySyncResult.conflict => DebugEvent.sync_conflict,
      StorySyncResult.pending => DebugEvent.sync_pending,
    });
    if (!mounted) return;
    setState(() {
      _chronicle = widget.store.open();
      _syncStatus = switch (result) {
        StorySyncResult.complete => 'A tárolási próba naprakész.',
        StorySyncResult.conflict =>
          'Eltérő meseváltozatok. Mindkét példány megmaradt.',
        StorySyncResult.pending => 'A szinkron függőben van.',
      };
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    debugEvent(DebugEvent.adventure_save_requested);
    if (!_form.currentState!.validate()) return;
    final id = _newId();
    final adventureId = _selected;
    final title = _title.text.trim();
    final details = _description.text.trim();
    try {
      final saved = widget.store.update((chronicle) {
        if (adventureId == null) {
          chronicle.createAdventure(id: id, title: title, description: details);
        } else {
          chronicle.addMilestone(
            adventureId,
            id: id,
            title: title,
            plannedOutcomes: [
              if (details.isNotEmpty) (id: id, description: details),
            ],
          );
        }
      });
      setState(() {
        _chronicle = saved;
        _selected = adventureId ?? id;
        _creating = false;
        _error = null;
      });
      debugEvent(DebugEvent.adventure_saved);
      _title.clear();
      _description.clear();
      unawaited(_sync());
    } on Exception {
      debugEvent(DebugEvent.adventure_save_failed);
      setState(
        () => _error = adventureId == null
            ? 'A kaland mentése sikertelen.'
            : 'A mérföldkő mentése sikertelen.',
      );
    } on StateError {
      debugEvent(DebugEvent.adventure_save_failed);
      setState(
        () => _error = adventureId == null
            ? 'A kaland mentése sikertelen.'
            : 'A mérföldkő mentése sikertelen.',
      );
    }
  }

  String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _updateSession(DebugEvent action, void Function(Chronicle) operation) {
    debugEvent(action);
    try {
      final saved = widget.store.update(operation);
      setState(() {
        _chronicle = saved;
        _error = null;
      });
      debugEvent(DebugEvent.session_change_saved);
      unawaited(_sync());
    } on Exception {
      debugEvent(DebugEvent.session_change_failed);
      setState(() => _error = 'A játékalkalom mentése sikertelen.');
    } on StateError {
      debugEvent(DebugEvent.session_change_failed);
      setState(() => _error = 'A játékalkalom mentése sikertelen.');
    }
  }

  Future<void> _recordOutcome(
    Adventure adventure,
    Session session,
    Milestone milestone,
  ) async {
    debugEvent(DebugEvent.outcome_editor_opened);
    var status = MilestoneStatus.completed;
    var description = '';
    final result =
        await showDialog<({MilestoneStatus status, String description})>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(milestone.title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<MilestoneStatus>(
                      value: status,
                      items: [
                        for (final item in MilestoneStatus.values)
                          if (item != MilestoneStatus.pending)
                            DropdownMenuItem(
                              value: item,
                              child: Text(_milestoneStatus(item)),
                            ),
                      ],
                      onChanged: (item) {
                        debugEvent(DebugEvent.field_edited);
                        update(() => status = item!);
                      },
                    ),
                    TextField(
                      onChanged: (value) {
                        debugEvent(DebugEvent.field_edited);
                        update(() => description = value.trim());
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tényleges kimenetel',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Mégse'),
                ),
                FilledButton(
                  onPressed: description.isEmpty
                      ? null
                      : () => Navigator.of(context)
                            .pop((status: status, description: description)),
                  child: const Text('Kimenetel mentése'),
                ),
              ],
            ),
          ),
        );
    if (!mounted) return;
    if (result == null) {
      debugEvent(DebugEvent.form_cancelled);
      return;
    }
    _updateSession(
      DebugEvent.outcome_save_requested,
      (chronicle) => chronicle.recordMilestoneOutcome(
        adventure.id,
        session.id,
        eventId: _newId(),
        milestoneId: milestone.id,
        status: result.status,
        outcome: result.description,
      ),
    );
  }

  Future<void> _recordSessionText(
    Adventure adventure,
    Session session, {
    required bool note,
  }) async {
    debugEvent(
      note ? DebugEvent.note_editor_opened : DebugEvent.event_editor_opened,
    );
    var text = '';
    var publishable = false;
    final result = await showDialog<({String text, bool publishable})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(note ? 'Új mesélői jegyzet' : 'Improvizált esemény'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) {
                    debugEvent(DebugEvent.field_edited);
                    update(() => text = value.trim());
                  },
                  decoration: InputDecoration(
                    labelText: note ? 'Jegyzet szövege' : 'Esemény leírása',
                  ),
                  maxLines: 3,
                ),
                if (!note)
                  CheckboxListTile(
                    title: const Text('Publikálható'),
                    value: publishable,
                    onChanged: (value) {
                      debugEvent(DebugEvent.field_edited);
                      update(() => publishable = value ?? false);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: text.isEmpty
                  ? null
                  : () =>
                        Navigator.of(context)
                            .pop((text: text, publishable: publishable)),
              child: Text(note ? 'Jegyzet mentése' : 'Esemény mentése'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      debugEvent(DebugEvent.form_cancelled);
      return;
    }
    final id = _newId();
    _updateSession(
      note ? DebugEvent.note_save_requested : DebugEvent.event_save_requested,
      (chronicle) {
        if (note) {
          chronicle.saveSessionNote(adventure.id, session.id, id, result.text);
        } else {
          chronicle.recordImprovisedEvent(
            adventure.id,
            session.id,
            id: id,
            description: result.text,
            visibility: result.publishable
                ? EventVisibility.publishable
                : EventVisibility.gmOnly,
          );
        }
      },
    );
  }

  String _milestoneStatus(MilestoneStatus status) => switch (status) {
    MilestoneStatus.pending => 'Függőben',
    MilestoneStatus.completed => 'Teljesítve',
    MilestoneStatus.partiallyCompleted => 'Részben teljesítve',
    MilestoneStatus.failed => 'Sikertelen',
    MilestoneStatus.skipped => 'Kihagyva',
  };

  @override
  Widget build(BuildContext context) {
    final adventure = _chronicle.adventures[_selected];
    final creatingMilestone = adventure != null;
    final active = adventure?.sessions.values
        .where((session) => session.isOpen)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.standalone ? 'Mesék' : 'Helyi kalandok'),
        actions: [
          if (adventure != null || widget.standalone)
            TextButton(
              onPressed: () {
                debugEvent(DebugEvent.settings_opened);
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => StorySettings(
                      settings: adventure == null
                          ? null
                          : StoryDiscordSettings('adventure:${adventure.id}'),
                    ),
                  ),
                );
              },
              child: const Text('Beállítások'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_syncStatus case final String status)
                Semantics(liveRegion: true, child: Text(status)),
              if (_creating)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _title,
                        onChanged: (_) => debugEvent(DebugEvent.field_edited),
                        decoration: InputDecoration(
                          labelText: creatingMilestone
                              ? 'Mérföldkő címe'
                              : 'Kaland címe',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? (creatingMilestone
                                  ? 'Add meg a mérföldkő címét.'
                                  : 'Add meg a kaland címét.')
                            : null,
                      ),
                      TextFormField(
                        controller: _description,
                        onChanged: (_) => debugEvent(DebugEvent.field_edited),
                        decoration: InputDecoration(
                          labelText: creatingMilestone
                              ? 'Tervezett kimenetel'
                              : 'Leírás',
                        ),
                        maxLines: 3,
                      ),
                      if (_error case final String error)
                        Semantics(liveRegion: true, child: Text(error)),
                      FilledButton(
                        onPressed: _save,
                        child: Text(
                          creatingMilestone
                              ? 'Mérföldkő mentése'
                              : 'Kaland mentése',
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          debugEvent(DebugEvent.form_cancelled);
                          _creating = false;
                          _error = null;
                          _title.clear();
                          _description.clear();
                        }),
                        child: const Text('Mégse'),
                      ),
                    ],
                  ),
                )
              else if (adventure != null) ...[
                Text(
                  adventure.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (adventure.description.isNotEmpty)
                  Text(adventure.description),
                const SizedBox(height: 16),
                Text(
                  'Mérföldkövek',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final milestone in adventure.milestones.values)
                  ListTile(
                    title: Text(milestone.title),
                    subtitle: Text(
                      [
                        _milestoneStatus(
                          adventure.progress[milestone.id]!.status,
                        ),
                        for (final outcome in milestone.plannedOutcomes)
                          outcome.description,
                      ].join('\n'),
                    ),
                    trailing: active == null
                        ? null
                        : TextButton(
                            onPressed: () =>
                                _recordOutcome(adventure, active, milestone),
                            child: const Text('Kimenetel rögzítése'),
                          ),
                  ),
                FilledButton(
                  onPressed: () => setState(() {
                    debugEvent(DebugEvent.milestone_form_opened);
                    _creating = true;
                  }),
                  child: const Text('Új mérföldkő'),
                ),
                if (_error case final String error)
                  Semantics(liveRegion: true, child: Text(error)),
                if (active == null)
                  OutlinedButton(
                    onPressed: () => _updateSession(
                      DebugEvent.session_start_requested,
                      (chronicle) => chronicle.startSession(
                        adventure.id,
                        id: _newId(),
                        startedAt: DateTime.now(),
                      ),
                    ),
                    child: const Text('Játékalkalom indítása'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _updateSession(
                      DebugEvent.session_close_requested,
                      (chronicle) => chronicle.closeSession(
                        adventure.id,
                        active.id,
                        DateTime.now(),
                      ),
                    ),
                    child: const Text('Játékalkalom lezárása'),
                  ),
                if (active != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            _recordSessionText(adventure, active, note: false),
                        child: const Text('Új improvizált esemény'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _recordSessionText(adventure, active, note: true),
                        child: const Text('Új mesélői jegyzet'),
                      ),
                    ],
                  ),
                for (final session in adventure.sessions.values)
                  ExpansionTile(
                    key: ValueKey((session.id, session.isOpen)),
                    initiallyExpanded: session.isOpen,
                    onExpansionChanged: (_) =>
                        debugEvent(DebugEvent.session_history_toggled),
                    title: Text(
                      session.isOpen
                          ? 'Aktív játékalkalom'
                          : 'Lezárt játékalkalom',
                    ),
                    children: [
                      for (final event in session.events)
                        ListTile(
                          title: Text(event.description),
                          subtitle: Text(
                            event.visibility == EventVisibility.publishable
                                ? 'Publikálható'
                                : 'Csak a mesélőnek',
                          ),
                        ),
                      if (session.notes.isNotEmpty)
                        const ListTile(title: Text('Mesélői jegyzetek')),
                      for (final note in session.notes.values)
                        ListTile(title: Text(note)),
                    ],
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    debugEvent(DebugEvent.story_list_opened);
                    _selected = null;
                    _error = null;
                  }),
                  child: Text(
                    widget.standalone
                        ? 'Vissza a mesékhez'
                        : 'Vissza a helyi kalandokhoz',
                  ),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => setState(() {
                    debugEvent(DebugEvent.adventure_form_opened);
                    _creating = true;
                  }),
                  child: Text(
                    widget.standalone ? 'Új mese' : 'Új önálló kaland',
                  ),
                ),
                if (widget.standalone)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const StoryDocumentPreview(),
                      ),
                    ),
                    child: const Text('Mese megnyitása fájlból'),
                  ),
                if (_chronicle.adventures.isEmpty)
                  const Text('Még nincs helyi kaland.'),
                for (final item in _chronicle.adventures.values)
                  ListTile(
                    title: Text(item.title),
                    onTap: () => setState(() {
                      debugEvent(DebugEvent.adventure_opened);
                      _selected = item.id;
                    }),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

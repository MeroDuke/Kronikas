import 'dart:math';

// Use the Material widgets from the pinned Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

class LocalAdventures extends StatefulWidget {
  const LocalAdventures({
    super.key,
    required this.store,
    required this.initial,
  });

  final LocalChronicleStore store;
  final Chronicle initial;

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

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
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
      _title.clear();
      _description.clear();
    } on Exception {
      setState(
        () => _error = adventureId == null
            ? 'A kaland mentése sikertelen.'
            : 'A mérföldkő mentése sikertelen.',
      );
    } on StateError {
      setState(
        () => _error = adventureId == null
            ? 'A kaland mentése sikertelen.'
            : 'A mérföldkő mentése sikertelen.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adventure = _chronicle.adventures[_selected];
    final creatingMilestone = adventure != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Helyi kalandok')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_creating)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _title,
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
                        switch (adventure.progress[milestone.id]!.status) {
                          MilestoneStatus.pending => 'Függőben',
                          MilestoneStatus.completed => 'Teljesítve',
                          MilestoneStatus.partiallyCompleted =>
                            'Részben teljesítve',
                          MilestoneStatus.failed => 'Sikertelen',
                          MilestoneStatus.skipped => 'Kihagyva',
                        },
                        for (final outcome in milestone.plannedOutcomes)
                          outcome.description,
                      ].join('\n'),
                    ),
                  ),
                FilledButton(
                  onPressed: () => setState(() => _creating = true),
                  child: const Text('Új mérföldkő'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected = null),
                  child: const Text('Vissza a helyi kalandokhoz'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => setState(() => _creating = true),
                  child: const Text('Új önálló kaland'),
                ),
                if (_chronicle.adventures.isEmpty)
                  const Text('Még nincs helyi kaland.'),
                for (final item in _chronicle.adventures.values)
                  ListTile(
                    title: Text(item.title),
                    onTap: () => setState(() => _selected = item.id),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Use the Material widgets from the pinned Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:kronikas_core/campaign_recap.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

class CampaignRecap extends StatefulWidget {
  const CampaignRecap({
    super.key,
    required this.store,
    required this.adventureId,
  });

  final LocalChronicleStore store;
  final String adventureId;

  @override
  State<CampaignRecap> createState() => _CampaignRecapState();
}

class _CampaignRecapState extends State<CampaignRecap> {
  final _text = TextEditingController();
  late final String _key;
  String? _saved;
  bool _approved = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    final current = widget.store.readRevision();
    final adventure = current.chronicle.adventures[widget.adventureId]!;
    final campaignId = adventure.campaignId;
    _key = campaignId != null
        ? 'campaignRecap:campaign:$campaignId'
        : 'campaignRecap:adventure:${adventure.id}';
    final stored = current.sync[_key];
    if (stored is Map && stored['text'] is String) {
      _saved = stored['text'] as String;
      _approved = stored['approved'] == true;
      _text.text = _saved!;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _generate() {
    final chronicle = widget.store.open();
    final text = buildCampaignRecap(
      chronicle,
      chronicle.adventures[widget.adventureId]!,
    );
    setState(() {
      if (text.isNotEmpty) _text.text = text;
      _status = text.isEmpty
          ? 'Még nincs publikálható esemény lezárt játékalkalomban.'
          : null;
    });
  }

  void _save({required bool approve}) {
    final text = _text.text.trim();
    try {
      final current = widget.store.readRevision();
      final previous = current.sync[_key];
      if ((previous is Map ? previous['text'] : null) != _saved ||
          (previous is Map && previous['approved'] == true) != _approved ||
          !widget.store.replaceIfCurrent(
            current.revision,
            sync: {
              ...current.sync,
              _key: {'text': text, 'approved': approve},
            },
          )) {
        setState(
          () => _status = 'Az értékelés közben módosult. Nyisd meg újra, majd próbáld meg ismét.',
        );
        return;
      }
      setState(() {
        _saved = text;
        _approved = approve;
        _status = approve ? 'Az értékelés jóváhagyva.' : 'A piszkozat mentve.';
      });
    } on Exception {
      setState(() => _status = 'Az értékelés mentése sikertelen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text.text.trim();
    final dirty = _saved != text;
    final approved = !dirty && _approved;
    return Scaffold(
      appBar: AppBar(title: const Text('Kampányértékelő')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              OutlinedButton(
                onPressed: text.isEmpty ? _generate : null,
                child: const Text('Összegzés készítése'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                decoration: const InputDecoration(labelText: 'Értékelés'),
                minLines: 5,
                maxLines: 12,
                onChanged: (_) => setState(() => _status = null),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: text.isEmpty || !dirty
                    ? null
                    : () => _save(approve: false),
                child: const Text('Piszkozat mentése'),
              ),
              OutlinedButton(
                onPressed: text.isEmpty || approved || dirty
                    ? null
                    : () => _save(approve: true),
                child: const Text('Értékelés jóváhagyása'),
              ),
              if ((_status ?? (approved ? 'Az értékelés jóváhagyva.' : null))
                  case final status?)
                Semantics(liveRegion: true, child: Text(status)),
            ],
          ),
        ),
      ),
    );
  }
}

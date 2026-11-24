import 'dart:convert';

import '../kronikas_core.dart';

typedef _Json = Map<String, Object?>;

String encodeChronicle(Chronicle chronicle) =>
    '${const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'campaigns': [
        for (final campaign in chronicle.campaigns.values) {'id': campaign.id, 'name': campaign.name},
      ],
      'adventures': [for (final adventure in chronicle.adventures.values) _encodeAdventure(adventure)],
    })}\n';

_Json _encodeAdventure(Adventure adventure) => {
  'id': adventure.id,
  'campaignId': adventure.campaignId,
  'title': adventure.title,
  'description': adventure.description,
  'scenes': [
    for (final scene in adventure.scenes.values)
      {'id': scene.id, 'title': scene.title, 'description': scene.description},
  ],
  'milestones': [
    for (final milestone in adventure.milestones.values)
      {
        'id': milestone.id,
        'title': milestone.title,
        'sceneId': milestone.sceneId,
        'plannedOutcomes': [
          for (final outcome in milestone.plannedOutcomes)
            {'id': outcome.id, 'description': outcome.description},
        ],
      },
  ],
  'notes': adventure.notes,
  'sessions': [
    for (final session in adventure.sessions.values)
      {
        'id': session.id,
        'startedAt': session.startedAt.toIso8601String(),
        'endedAt': session.endedAt?.toIso8601String(),
        'notes': session.notes,
        'events': [
          for (final event in session.events)
            {
              'id': event.id,
              'type': event.type.name,
              'description': event.description,
              'visibility': event.visibility.name,
              if (event.type == SessionEventType.milestoneUpdate) ...{
                'milestoneId': event.milestoneId,
                'status': event.milestoneStatus?.name,
                'plannedOutcomeId': event.plannedOutcomeId,
              },
            },
        ],
      },
  ],
};

Chronicle decodeChronicle(String text) {
  try {
    final snapshot = jsonDecode(text) as _Json;
    final version = snapshot['schemaVersion'];
    if (version is! int || version != 1) {
      throw FormatException('Unsupported Chronicle schema version: $version');
    }
    final chronicle = Chronicle();
    for (final campaign in _objects(snapshot, 'campaigns')) {
      chronicle.createCampaign(
        id: campaign['id'] as String,
        name: campaign['name'] as String,
      );
    }
    for (final adventure in _objects(snapshot, 'adventures')) {
      _restoreAdventure(chronicle, adventure);
    }
    return chronicle;
  } on TypeError {
    throw const FormatException('Invalid Chronicle snapshot fields.');
  } on ArgumentError catch (error) {
    throw FormatException('Invalid Chronicle snapshot: ${error.message}');
  } on StateError catch (error) {
    throw FormatException('Invalid Chronicle snapshot: ${error.message}');
  }
}

void _restoreAdventure(Chronicle chronicle, _Json data) {
  final id = data['id'] as String;
  chronicle.createAdventure(
    id: id,
    title: data['title'] as String,
    description: data['description'] as String,
    campaignId: data['campaignId'] as String?,
  );
  for (final scene in _objects(data, 'scenes')) {
    chronicle.addScene(
      id,
      id: scene['id'] as String,
      title: scene['title'] as String,
      description: scene['description'] as String,
    );
  }
  for (final milestone in _objects(data, 'milestones')) {
    chronicle.addMilestone(
      id,
      id: milestone['id'] as String,
      title: milestone['title'] as String,
      sceneId: milestone['sceneId'] as String?,
      plannedOutcomes: [
        for (final outcome in _objects(milestone, 'plannedOutcomes'))
          (
            id: outcome['id'] as String,
            description: outcome['description'] as String,
          ),
      ],
    );
  }
  for (final note in (data['notes'] as _Json).entries) {
    chronicle.saveAdventureNote(id, note.key, note.value as String);
  }
  for (final session in _objects(data, 'sessions')) {
    _restoreSession(chronicle, id, session);
  }
}

void _restoreSession(Chronicle chronicle, String adventureId, _Json data) {
  final id = data['id'] as String;
  chronicle.startSession(
    adventureId,
    id: id,
    startedAt: DateTime.parse(data['startedAt'] as String),
  );
  for (final note in (data['notes'] as _Json).entries) {
    chronicle.saveSessionNote(adventureId, id, note.key, note.value as String);
  }
  for (final event in _objects(data, 'events')) {
    final eventId = event['id'] as String;
    final description = event['description'] as String;
    final visibility = EventVisibility.values.byName(
      event['visibility'] as String,
    );
    switch (SessionEventType.values.byName(event['type'] as String)) {
      case SessionEventType.milestoneUpdate:
        chronicle.recordMilestoneOutcome(
          adventureId,
          id,
          eventId: eventId,
          milestoneId: event['milestoneId'] as String,
          status: MilestoneStatus.values.byName(event['status'] as String),
          outcome: description,
          plannedOutcomeId: event['plannedOutcomeId'] as String?,
          visibility: visibility,
        );
      case SessionEventType.improvised:
        chronicle.recordImprovisedEvent(
          adventureId,
          id,
          id: eventId,
          description: description,
          visibility: visibility,
        );
    }
  }
  if (data['endedAt'] case final String endedAt) {
    chronicle.closeSession(adventureId, id, DateTime.parse(endedAt));
  } else if (data['endedAt'] != null) {
    throw const FormatException('Invalid session end time.');
  }
}

Iterable<_Json> _objects(_Json data, String key) =>
    (data[key] as List<Object?>).cast<_Json>();

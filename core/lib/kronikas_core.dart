/// Entry point for the platform-independent Krónikás application core.
library kronikas_core;

enum MilestoneStatus { pending, completed, partiallyCompleted, failed, skipped }

enum EventVisibility { gmOnly, publishable }

enum SessionEventType { milestoneUpdate, improvised }

final class Campaign {
  Campaign._(this.id, this._name);

  final String id;
  String _name;
  String get name => _name;
}

typedef Scene = ({String id, String title, String description});
typedef PlannedOutcome = ({String id, String description});
typedef Milestone = ({
  String id,
  String title,
  String? sceneId,
  List<PlannedOutcome> plannedOutcomes,
});
typedef SessionEvent = ({
  String id,
  int sequence,
  SessionEventType type,
  String description,
  EventVisibility visibility,
  String? sceneId,
  String? milestoneId,
  MilestoneStatus? milestoneStatus,
  String? plannedOutcomeId,
});
typedef MilestoneProgress = ({
  MilestoneStatus status,
  String? outcome,
  String? eventId,
});

final class Adventure {
  Adventure._(this.id, this.campaignId, this._title, this._description);

  final String id;
  final String? campaignId;
  String _title;
  String _description;
  final _scenes = <String, Scene>{};
  final _milestones = <String, Milestone>{};
  final _progress = <String, MilestoneProgress>{};
  final _notes = <String, String>{};
  final _sessions = <String, Session>{};

  String get title => _title;
  String get description => _description;
  Map<String, Scene> get scenes => Map.unmodifiable(_scenes);
  Map<String, Milestone> get milestones => Map.unmodifiable(_milestones);
  Map<String, MilestoneProgress> get progress => Map.unmodifiable(_progress);
  Map<String, String> get notes => Map.unmodifiable(_notes);
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);
}

final class Session {
  Session._(this.id, this.startedAt);

  final String id;
  final DateTime startedAt;
  DateTime? _endedAt;
  final _events = <SessionEvent>[];
  final _notes = <String, String>{};

  DateTime? get endedAt => _endedAt;
  bool get isOpen => _endedAt == null;
  List<SessionEvent> get events => List.unmodifiable(_events);
  Map<String, String> get notes => Map.unmodifiable(_notes);
}

/// In-memory application operations for preparing and running adventures.
final class Chronicle {
  final _campaigns = <String, Campaign>{};
  final _adventures = <String, Adventure>{};

  Map<String, Campaign> get campaigns => Map.unmodifiable(_campaigns);
  Map<String, Adventure> get adventures => Map.unmodifiable(_adventures);

  Campaign createCampaign({required String id, required String name}) {
    _requireNewId(_campaigns, id);
    return _campaigns[id] = Campaign._(id, _requiredText(name, 'name'));
  }

  void renameCampaign(String id, String name) {
    _lookup(_campaigns, id, 'campaign')._name = _requiredText(name, 'name');
  }

  Adventure createAdventure({
    required String id,
    required String title,
    String description = '',
    String? campaignId,
  }) {
    _requireNewId(_adventures, id);
    if (campaignId != null) _lookup(_campaigns, campaignId, 'campaign');
    return _adventures[id] = Adventure._(
      id,
      campaignId,
      _requiredText(title, 'title'),
      description,
    );
  }

  void editAdventure(
    String id, {
    required String title,
    required String description,
  }) {
    final adventure = _adventure(id);
    adventure._title = _requiredText(title, 'title');
    adventure._description = description;
  }

  void addScene(
    String adventureId, {
    required String id,
    required String title,
    String description = '',
  }) {
    final scenes = _adventure(adventureId)._scenes;
    _requireNewId(scenes, id);
    scenes[id] = (
      id: id,
      title: _requiredText(title, 'title'),
      description: description,
    );
  }

  void addMilestone(
    String adventureId, {
    required String id,
    required String title,
    String? sceneId,
    Iterable<PlannedOutcome> plannedOutcomes = const [],
  }) {
    final adventure = _adventure(adventureId);
    _requireNewId(adventure._milestones, id);
    if (sceneId != null) _lookup(adventure._scenes, sceneId, 'scene');
    final outcomes = List<PlannedOutcome>.unmodifiable(plannedOutcomes);
    final outcomeIds = <String>{};
    for (final outcome in outcomes) {
      _requiredText(outcome.id, 'outcome id');
      _requiredText(outcome.description, 'outcome description');
      if (!outcomeIds.add(outcome.id)) {
        throw ArgumentError.value(outcome.id, 'outcome id', 'Duplicate ID');
      }
    }
    adventure._milestones[id] = (
      id: id,
      title: _requiredText(title, 'title'),
      sceneId: sceneId,
      plannedOutcomes: outcomes,
    );
    adventure._progress[id] = (
      status: MilestoneStatus.pending,
      outcome: null,
      eventId: null,
    );
  }

  void saveAdventureNote(String adventureId, String noteId, String text) {
    _adventure(adventureId)
        ._notes[_requiredText(noteId, 'note id')] = _requiredText(
      text,
      'note',
    );
  }

  void saveSessionNote(
    String adventureId,
    String sessionId,
    String noteId,
    String text,
  ) {
    _openSession(_adventure(adventureId), sessionId)._notes[_requiredText(
      noteId,
      'note id',
    )] = _requiredText(
      text,
      'note',
    );
  }

  Session startSession(
    String adventureId, {
    required String id,
    required DateTime startedAt,
  }) {
    final sessions = _adventure(adventureId)._sessions;
    _requireNewId(sessions, id);
    if (sessions.values.any((session) => session.isOpen)) {
      throw StateError('An adventure already has an open session.');
    }
    return sessions[id] = Session._(id, startedAt.toUtc());
  }

  void closeSession(String adventureId, String sessionId, DateTime endedAt) {
    final session = _openSession(_adventure(adventureId), sessionId);
    if (endedAt.isBefore(session.startedAt)) {
      throw ArgumentError.value(
        endedAt,
        'endedAt',
        'Before the session started',
      );
    }
    session._endedAt = endedAt.toUtc();
  }

  SessionEvent recordMilestoneOutcome(
    String adventureId,
    String sessionId, {
    required String eventId,
    required String milestoneId,
    required MilestoneStatus status,
    required String outcome,
    String? plannedOutcomeId,
    EventVisibility visibility = EventVisibility.gmOnly,
  }) {
    final adventure = _adventure(adventureId);
    final session = _openSession(adventure, sessionId);
    final milestone = _lookup(adventure._milestones, milestoneId, 'milestone');
    if (plannedOutcomeId != null &&
        !milestone.plannedOutcomes.any(
          (entry) => entry.id == plannedOutcomeId,
        )) {
      throw ArgumentError.value(
        plannedOutcomeId,
        'plannedOutcomeId',
        'Unknown outcome',
      );
    }
    _requireNewEventId(adventure, eventId);
    final event = (
      id: eventId,
      sequence: session._events.length + 1,
      type: SessionEventType.milestoneUpdate,
      description: _requiredText(outcome, 'outcome'),
      visibility: visibility,
      sceneId: milestone.sceneId,
      milestoneId: milestoneId,
      milestoneStatus: status,
      plannedOutcomeId: plannedOutcomeId,
    );
    session._events.add(event);
    adventure._progress[milestoneId] = (
      status: status,
      outcome: outcome,
      eventId: eventId,
    );
    return event;
  }

  SessionEvent recordImprovisedEvent(
    String adventureId,
    String sessionId, {
    required String id,
    required String description,
    EventVisibility visibility = EventVisibility.gmOnly,
  }) {
    final adventure = _adventure(adventureId);
    final session = _openSession(adventure, sessionId);
    _requireNewEventId(adventure, id);
    final SessionEvent event = (
      id: id,
      sequence: session._events.length + 1,
      type: SessionEventType.improvised,
      description: _requiredText(description, 'description'),
      visibility: visibility,
      sceneId: null,
      milestoneId: null,
      milestoneStatus: null,
      plannedOutcomeId: null,
    );
    session._events.add(event);
    return event;
  }

  Adventure _adventure(String id) => _lookup(_adventures, id, 'adventure');

  Session _openSession(Adventure adventure, String id) {
    final session = _lookup(adventure._sessions, id, 'session');
    if (!session.isOpen) throw StateError('Session is closed.');
    return session;
  }

  void _requireNewEventId(Adventure adventure, String id) {
    _requiredText(id, 'event id');
    for (final session in adventure._sessions.values) {
      if (session._events.any((event) => event.id == id)) {
        throw ArgumentError.value(id, 'event id', 'Duplicate ID');
      }
    }
  }
}

T _lookup<T>(Map<String, T> entries, String id, String kind) =>
    entries[id] ?? (throw ArgumentError.value(id, kind, 'Unknown ID'));

void _requireNewId(Map<String, Object> entries, String id) {
  _requiredText(id, 'id');
  if (entries.containsKey(id)) {
    throw ArgumentError.value(id, 'id', 'Duplicate ID');
  }
}

String _requiredText(String value, String name) {
  if (value.trim().isEmpty)
    throw ArgumentError.value(value, name, 'Blank value');
  return value;
}

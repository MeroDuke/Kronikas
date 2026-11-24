import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';

import 'sync_check.dart';

final start = DateTime.utc(2026, 11, 24, 18);
final end = DateTime.utc(2026, 11, 24, 20);

Future<void> main(List<String> args) async {
  if (args.length == 2 && args.first == '--interrupt-update') {
    final store = LocalChronicleStore(Directory(args.last));
    store.update((chronicle) {
      chronicle.editAdventure('a', title: 'Uncommitted child', description: '');
      // Leave representative incomplete staging data and bypass cleanup.
      final pending = store.directory.createTempSync('.pending-');
      File.fromUri(pending.uri.resolve('snapshot.json'))
          .writeAsStringSync('{"schemaVersion":1', flush: true);
      exit(73);
    });
    throw StateError('The interruption probe unexpectedly returned.');
  }
  final checks = <String, FutureOr<void> Function()>{
    'campaign and one-shot preparation': _preparation,
    'outcomes and continuity across sessions': _continuity,
    'invalid operations preserve state': _invalidOperations,
    'versioned local snapshot and continued session': _localRoundTrip,
    'interrupted update preserves committed state': _interruptedUpdate,
    'unsupported schema preserves the original data': _unsupportedSchema,
    ...syncChecks,
  };
  final failures = <String, String>{};
  for (final MapEntry(:key, :value) in checks.entries) {
    try {
      await value();
      stdout.writeln('PASS $key');
    } catch (error, stack) {
      failures[key] = error.toString();
      stderr.writeln('FAIL $key: $error\n$stack');
    }
  }
  File(args.single).writeAsStringSync(
    jsonEncode({
      'total': checks.length,
      'passed': checks.length - failures.length,
      'failed': failures.length,
      'skipped': 0,
      'failures': failures,
    }),
  );
}

void _localRoundTrip() {
  _withStore((store) {
    final fixture = File('test/fixtures/chronicle_v1.json');
    fixture.copySync(
      File.fromUri(store.directory.uri.resolve('revision-1.json')).path,
    );
    final initial = store.open().adventures['river']!;
    _check(initial.campaignId == 'valley', 'Campaign reference');
    _check(initial.notes['weather'] == 'High water', 'Adventure note');
    _check(
      initial.progress['cross']?.status == MilestoneStatus.failed,
      'Restored status',
    );
    _check(
      initial.sessions['first']?.notes['crew'] == 'Ferry crew helped',
      'Session note',
    );
    store.update((chronicle) {
      chronicle.createAdventure(id: 'solo', title: 'One-shot');
      chronicle.startSession('river', id: 'second', startedAt: end);
      chronicle.recordMilestoneOutcome(
        'river',
        'second',
        eventId: 'success',
        milestoneId: 'cross',
        status: MilestoneStatus.completed,
        outcome: 'The repaired ferry crossed.',
        visibility: EventVisibility.publishable,
      );
      chronicle.recordImprovisedEvent(
        'river',
        'second',
        id: 'traveller',
        description: 'A traveller arrived.',
      );
    });
    final reopened = LocalChronicleStore(store.directory).open();
    final adventure = reopened.adventures['river']!;
    final first = adventure.sessions['first']!;
    final second = adventure.sessions['second']!;
    _check(
      reopened.adventures['solo']?.campaignId == null,
      'One-shot retained',
    );
    _check(
      first.endedAt == end &&
          first.events.single.description == 'The ferry broke.',
      'Prior history',
    );
    _check(
      second.isOpen && second.events.last.sequence == 2,
      'Open session and order',
    );
    _check(
      second.events.first.visibility == EventVisibility.publishable,
      'Visibility retained',
    );
    _check(
      adventure.progress['cross']?.eventId == 'success',
      'Progress points to new event',
    );
    _check(
      adventure.progress['cross']?.status == MilestoneStatus.completed,
      'Progress restored',
    );
    _check(
      adventure.milestones['cross']?.plannedOutcomes.single.id == 'ferry',
      'Original plan retained',
    );
  });
}

void _interruptedUpdate() {
  _withStore((store) {
    store.update((chronicle) {
      chronicle.createAdventure(id: 'a', title: 'Original');
    });
    _throws<StateError>(
      () => store.update((chronicle) {
        chronicle.editAdventure('a', title: 'Uncommitted', description: '');
        throw StateError('Interrupted operation');
      }),
    );
    final child = Process.runSync(Platform.resolvedExecutable, [
      'run',
      'test/chronicle_check.dart',
      '--interrupt-update',
      store.directory.path,
    ]);
    _check(
      child.exitCode == 73,
      'Child did not reach interruption: ${child.stderr}',
    );
    final reopened = LocalChronicleStore(store.directory);
    _check(
      reopened.open().adventures['a']?.title == 'Original',
      'Ignore incomplete staging',
    );
    reopened.update((chronicle) {
      _throws<StateError>(() => store.update((_) {}));
      chronicle.editAdventure('a', title: 'Committed', description: '');
    });
    _check(
      store.open().adventures['a']?.title == 'Committed',
      'Read new committed revision',
    );
  });
}

void _unsupportedSchema() {
  _withStore((store) {
    final revision = File.fromUri(
      store.directory.uri.resolve('revision-1.json'),
    );
    const original = '{"schemaVersion":2,"campaigns":[],"adventures":[]}';
    revision.writeAsStringSync(original);
    _throws<FormatException>(store.open);
    _throws<FormatException>(
      () => store.update((_) => throw StateError('Must not run')),
    );
    _check(
      revision.readAsStringSync() == original,
      'Preserve unsupported snapshot',
    );
    _check(
      !File.fromUri(store.directory.uri.resolve('revision-2.json'))
          .existsSync(),
      'No replacement snapshot',
    );
  });
}

void _withStore(void Function(LocalChronicleStore) test) {
  final directory = Directory.systemTemp.createTempSync('kronikas-test-');
  try {
    test(LocalChronicleStore(directory));
  } finally {
    directory.deleteSync(recursive: true);
  }
}

void _preparation() {
  final chronicle = Chronicle();
  final campaign = chronicle.createCampaign(id: 'c', name: 'River stories');
  final linked = chronicle.createAdventure(
    id: 'linked',
    title: 'River crossing',
    campaignId: campaign.id,
  );
  final oneShot = chronicle.createAdventure(id: 'solo', title: 'Old mill');
  chronicle.renameCampaign(campaign.id, 'Northern stories');
  chronicle.editAdventure(
    oneShot.id,
    title: 'The old mill',
    description: 'A short adventure',
  );
  chronicle.saveAdventureNote(oneShot.id, 'note', 'Hidden trap');
  chronicle.saveAdventureNote(oneShot.id, 'note', 'Trap moved');
  _check(chronicle.campaigns['c']?.name == 'Northern stories', 'Rename');
  _check(linked.campaignId == campaign.id, 'Campaign link');
  _check(oneShot.campaignId == null, 'Independent one-shot');
  _check(oneShot.id == 'solo' && oneShot.title == 'The old mill', 'Edit');
  _check(oneShot.description == 'A short adventure', 'Edit description');
  _check(oneShot.notes['note'] == 'Trap moved', 'Update note');
}

void _continuity() {
  final chronicle = Chronicle();
  final adventure = chronicle.createAdventure(id: 'a', title: 'The river');
  chronicle.addScene('a', id: 's', title: 'Riverbank');
  chronicle.addMilestone('a', id: 'first', title: 'Find the ferryman');
  chronicle.addMilestone(
    'a',
    id: 'cross',
    title: 'Cross the river',
    sceneId: 's',
    plannedOutcomes: [(id: 'ferry', description: 'Cross by ferry')],
  );
  final first = chronicle.startSession('a', id: 'one', startedAt: start);
  chronicle.saveSessionNote('a', 'one', 'note', 'High water');
  chronicle.recordMilestoneOutcome(
    'a',
    'one',
    eventId: 'e1',
    milestoneId: 'cross',
    status: MilestoneStatus.failed,
    outcome: 'The ferry broke.',
  );
  final improvised = chronicle.recordImprovisedEvent(
    'a',
    'one',
    id: 'e2',
    description: 'A traveller arrived.',
  );
  chronicle.closeSession('a', 'one', end);
  _check(
    first.endedAt == end && first.notes['note'] == 'High water',
    'Closure',
  );
  _check(
    improvised.sequence == 2 && improvised.sceneId == null,
    'Improvisation',
  );
  _check(
    adventure.progress['cross']?.status == MilestoneStatus.failed,
    'Failed state',
  );

  final second = chronicle.startSession('a', id: 'two', startedAt: end);
  chronicle.recordMilestoneOutcome(
    'a',
    'two',
    eventId: 'e3',
    milestoneId: 'cross',
    status: MilestoneStatus.completed,
    outcome: 'The repaired ferry crossed.',
    plannedOutcomeId: 'ferry',
    visibility: EventVisibility.publishable,
  );
  final progress = adventure.progress['cross'];
  _check(
    progress?.status == MilestoneStatus.completed && progress?.eventId == 'e3',
    'Current progress',
  );
  _check(progress?.outcome == 'The repaired ferry crossed.', 'Current outcome');
  _check(
    adventure.progress['first']?.status == MilestoneStatus.pending,
    'Nonlinear order',
  );
  _check(
    first.events.first.milestoneStatus == MilestoneStatus.failed,
    'Historical status',
  );
  _check(
    first.events.first.description == 'The ferry broke.',
    'Historical outcome',
  );
  _check(
    first.events.first.visibility == EventVisibility.gmOnly,
    'Safe default visibility',
  );
  _check(second.events.single.sequence == 1, 'Per-session order');
  _check(
    second.events.single.visibility == EventVisibility.publishable,
    'Explicit visibility',
  );
  _check(
    second.events.single.plannedOutcomeId == 'ferry',
    'Planned outcome reference',
  );
  _check(
    adventure.milestones['cross']?.plannedOutcomes.single.description ==
        'Cross by ferry',
    'Original plan',
  );
}

void _invalidOperations() {
  final chronicle = Chronicle();
  final adventure = chronicle.createAdventure(id: 'a', title: 'A');
  chronicle.createAdventure(id: 'b', title: 'B');
  chronicle.addScene('b', id: 'foreign-scene', title: 'B scene');
  _throws<ArgumentError>(
    () => chronicle.addMilestone(
      'a',
      id: 'wrong',
      title: 'Wrong',
      sceneId: 'foreign-scene',
    ),
  );
  _check(
    adventure.milestones.isEmpty && adventure.progress.isEmpty,
    'Reject partial plan',
  );
  chronicle.addMilestone('a', id: 'm', title: 'A milestone');
  final first = chronicle.startSession('a', id: 'one', startedAt: start);
  _throws<StateError>(
    () => chronicle.startSession('a', id: 'other', startedAt: start),
  );
  _throws<ArgumentError>(
    () => chronicle.recordMilestoneOutcome(
      'a',
      'one',
      eventId: 'e',
      milestoneId: 'm',
      status: MilestoneStatus.completed,
      outcome: 'Done',
      plannedOutcomeId: 'missing',
    ),
  );
  _check(
    first.events.isEmpty &&
        adventure.progress['m']?.status == MilestoneStatus.pending,
    'Reject partial outcome',
  );
  chronicle.recordImprovisedEvent(
    'a',
    'one',
    id: 'e',
    description: 'First event',
  );
  _throws<UnsupportedError>(() => first.events.clear());
  chronicle.closeSession('a', 'one', end);
  _throws<StateError>(
    () => chronicle.recordImprovisedEvent(
      'a',
      'one',
      id: 'later',
      description: 'Late event',
    ),
  );
  final second = chronicle.startSession('a', id: 'two', startedAt: end);
  _throws<ArgumentError>(
    () => chronicle.recordImprovisedEvent(
      'a',
      'two',
      id: 'e',
      description: 'Duplicate event',
    ),
  );
  _check(first.events.length == 1 && second.events.isEmpty, 'Preserve history');
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _throws<T extends Object>(void Function() action) {
  try {
    action();
  } on T {
    return;
  }
  throw StateError('Expected $T.');
}

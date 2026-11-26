import 'dart:io';

// Use the Material widgets from the pinned Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_platform_probe/local_adventures.dart';

void main() {
  testWidgets(
    'generates a public recap, reopens approval and invalidates edits',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('kronikas-recap-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final store = LocalChronicleStore(directory);
      store.update((data) {
        data.createAdventure(id: 'a', title: 'Teszt mese');
        data.addMilestone('a', id: 'm', title: 'Terv');
        data.startSession('a', id: 'first', startedAt: DateTime.utc(2026));
        data.recordImprovisedEvent(
          'a',
          'first',
          id: 'visible',
          description: 'Átkeltek a folyón.',
          visibility: EventVisibility.publishable,
        );
        data.recordImprovisedEvent(
          'a',
          'first',
          id: 'private',
          description: 'Titkos esemény.',
        );
        data.saveSessionNote('a', 'first', 'note', 'Belső jegyzet.');
        data.recordMilestoneOutcome(
          'a',
          'first',
          eventId: 'skipped',
          milestoneId: 'm',
          status: MilestoneStatus.skipped,
          outcome: 'Kimaradt terv.',
          visibility: EventVisibility.publishable,
        );
        data.closeSession('a', 'first', DateTime.utc(2026, 1, 1, 1));
        data.startSession(
          'a',
          id: 'second',
          startedAt: DateTime.utc(2026, 1, 2),
        );
        data.recordImprovisedEvent(
          'a',
          'second',
          id: 'ongoing',
          description: 'Aktív esemény.',
          visibility: EventVisibility.publishable,
        );
      });
      Future<void> tap(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: LocalAdventures(store: store, initial: store.open()),
        ),
      );
      await tap('Teszt mese');
      await tap('Kampányértékelő');
      await tap('Összegzés készítése');
      final field = find.byType(TextField);
      final text = tester.widget<TextField>(field).controller!.text;
      expect(text, contains('Átkeltek a folyón.'));
      for (final excluded in [
        'Titkos esemény.',
        'Belső jegyzet.',
        'Kimaradt terv.',
        'Aktív esemény.',
      ]) {
        expect(text, isNot(contains(excluded)));
      }
      await tap('Piszkozat mentése');
      await tap('Értékelés jóváhagyása');
      expect(find.text('Az értékelés jóváhagyva.'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tap('Kampányértékelő');
      expect(find.text('Az értékelés jóváhagyva.'), findsOneWidget);
      await tester.enterText(field, 'Szerkesztett értékelés.');
      await tester.pumpAndSettle();
      await tap('Piszkozat mentése');
      expect(find.text('Az értékelés jóváhagyva.'), findsNothing);
      expect(store.readRevision().sync['campaignRecap:adventure:a'], {
        'text': 'Szerkesztett értékelés.',
        'approved': false,
      });
    },
  );
}

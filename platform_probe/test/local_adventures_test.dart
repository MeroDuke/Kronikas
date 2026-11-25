import 'dart:io';

// Use the Material widgets bundled with the pinned SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_core/local_chronicle_store.dart';
import 'package:kronikas_platform_probe/local_adventures.dart';

void main() {
  testWidgets(
    'Local adventure and milestone validate, save and reopen from disk',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'kronikas-local-ui-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));

      Future<void> openWorkspace() async {
        final store = LocalChronicleStore(directory);
        await tester.pumpWidget(
          MaterialApp(
            home: LocalAdventures(store: store, initial: store.open()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openWorkspace();
      expect(find.text('Még nincs helyi kaland.'), findsOneWidget);
      await tester.tap(find.text('Új önálló kaland'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaland mentése'));
      await tester.pumpAndSettle();
      expect(find.text('Add meg a kaland címét.'), findsOneWidget);
      expect(LocalChronicleStore(directory).open().adventures, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kaland címe'),
        'Folyami átkelés',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Leírás'),
        'Szintetikus kaland.',
      );
      await tester.tap(find.text('Kaland mentése'));
      await tester.pumpAndSettle();
      expect(find.text('Folyami átkelés'), findsOneWidget);
      expect(find.text('Szintetikus kaland.'), findsOneWidget);

      await tester.tap(find.text('Új mérföldkő'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mérföldkő mentése'));
      await tester.pumpAndSettle();
      expect(find.text('Add meg a mérföldkő címét.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mérföldkő címe'),
        'Átjutás a túlpartra',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tervezett kimenetel'),
        'A komp eléri a partot.',
      );
      await tester.tap(find.text('Mérföldkő mentése'));
      await tester.pumpAndSettle();
      expect(find.text('Átjutás a túlpartra'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await openWorkspace();
      await tester.tap(find.text('Folyami átkelés'));
      await tester.pumpAndSettle();
      expect(find.text('Szintetikus kaland.'), findsOneWidget);
      final saved = LocalChronicleStore(directory)
          .open()
          .adventures
          .values
          .single;
      expect(saved.campaignId, isNull);
      expect(find.text('Átjutás a túlpartra'), findsOneWidget);
      expect(find.text('Függőben\nA komp eléri a partot.'), findsOneWidget);
      expect(
        saved.milestones.values.single.plannedOutcomes.single.description,
        'A komp eléri a partot.',
      );
    },
  );

  testWidgets(
    'Local session records a milestone result and survives reopening',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'kronikas-session-ui-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      LocalChronicleStore(directory).update((chronicle) {
        chronicle.createAdventure(id: 'river', title: 'Folyami átkelés');
        chronicle.addMilestone('river', id: 'ferry', title: 'Komp');
      });

      Future<void> tap(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> reopen() async {
        final store = LocalChronicleStore(directory);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: LocalAdventures(store: store, initial: store.open()),
          ),
        );
        await tap('Folyami átkelés');
      }

      await reopen();
      await tap('Játékalkalom indítása');
      await tap('Kimenetel rögzítése');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kimenetel mentése'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'A komp átkelt.');
      await tester.pumpAndSettle();
      await tap('Kimenetel mentése');
      expect(find.text('Teljesítve'), findsOneWidget);

      expect(
        LocalChronicleStore(directory)
            .open()
            .adventures['river']!
            .sessions
            .values
            .single
            .events
            .single
            .description,
        'A komp átkelt.',
      );
      await reopen();
      expect(find.text('Aktív játékalkalom'), findsOneWidget);
      expect(find.text('A komp átkelt.'), findsOneWidget);
      await tap('Játékalkalom lezárása');
      await reopen();
      await tap('Lezárt játékalkalom');
      expect(find.text('A komp átkelt.'), findsOneWidget);
      expect(find.text('Kimenetel rögzítése'), findsNothing);
      final saved = LocalChronicleStore(directory).open().adventures['river']!;
      expect(saved.progress['ferry']!.status, MilestoneStatus.completed);
      expect(
        saved.sessions.values.single.events.single.visibility,
        EventVisibility.gmOnly,
      );
    },
  );
}

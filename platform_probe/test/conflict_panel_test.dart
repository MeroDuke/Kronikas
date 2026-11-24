import 'dart:io';

// The application uses the Material widgets bundled with the pinned SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/story_picker_walkthrough.dart';

void main() {
  for (final (choice, title) in [
    ('Helyi érték', 'Helyi átkelés'),
    ('Távoli érték', 'Távoli átkelés'),
  ]) {
    testWidgets('Saves $choice', (tester) async {
      await _openConflict(tester);
      await _tap(tester, choice);
      expect(find.text('Kiválasztva: $title'), findsOneWidget);
      await _tap(tester, 'Feloldás mentése');
      expect(find.text('A feloldás mentve.'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
    });
  }

  testWidgets(
    'Refreshes stale approval, saves custom title and opens originals',
    (tester) async {
      await _openConflict(tester);
      await _tap(tester, 'Helyi érték');
      await _tap(tester, 'Szimulált távoli módosítás');
      await _tap(tester, 'Feloldás mentése');
      expect(
        find.text('A változatok frissültek. Erősítsd meg újra.'),
        findsOneWidget,
      );
      expect(find.text('Távoli: Friss távoli átkelés'), findsOneWidget);

      final input = find.byType(TextField);
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Merged title');
      await tester.pumpAndSettle();
      expect(find.text('Kiválasztva: Merged title'), findsOneWidget);
      await _tap(tester, 'Feloldás mentése');
      expect(find.text('A feloldás mentve.'), findsOneWidget);
      expect(find.text('Merged title'), findsOneWidget);

      await _tap(tester, 'Eredeti helyi változat megnyitása');
      expect(
        find.text('Visszaállított példány: Helyi átkelés'),
        findsOneWidget,
      );
      await _tap(tester, 'Eredeti távoli változat megnyitása');
      expect(
        find.text('Visszaállított példány: Friss távoli átkelés'),
        findsOneWidget,
      );
      expect(find.text('Merged title'), findsOneWidget);
    },
  );
}

Future<void> _openConflict(WidgetTester tester) async {
  final directory = Directory.systemTemp.createTempSync('kronikas-widget-');
  addTearDown(() => directory.deleteSync(recursive: true));
  await tester.pumpWidget(buildWalkthroughApp(directory));
  await _tap(tester, 'Repó csatlakoztatása');
  await _tap(tester, 'Teszt mese');
  await _tap(tester, 'Mese szinkronizálása');
  expect(find.text('Helyi: Helyi átkelés'), findsOneWidget);
  expect(find.text('Távoli: Távoli átkelés'), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

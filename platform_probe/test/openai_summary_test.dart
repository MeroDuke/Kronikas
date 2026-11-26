// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_platform_probe/discord_share.dart';
import 'package:kronikas_platform_probe/openai_summary.dart';
import 'package:kronikas_platform_probe/story_discord_settings.dart';

void main() {
  test('reads only completed assistant text', () {
    expect(
      readOpenAiSummary(
        '{"status":"completed","output":[{"type":"reasoning"},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Lezárás."}]}]}',
      ),
      'Lezárás.',
    );
    expect(
      () => readOpenAiSummary('{"status":"incomplete","output":[]}'),
      throwsA(isA<OpenAiSummaryException>()),
    );
  });

  testWidgets('shows the cost warning every time after declining', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiscordShare(
          message: '',
          title: 'Összegzés',
          destination: (
            label: 'Teszt',
            webhook: Uri.parse('https://discord.com/api/webhooks/1/synthetic'),
          ),
          storyContext: 'Tesztmese',
          settings: const StoryDiscordSettings('synthetic'),
        ),
      ),
    );
    final button = find.widgetWithText(FilledButton, 'Küldés Discordra');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Fizetős OpenAI-generálás'), findsOneWidget);
      await tester.tap(find.text('Elutasítom'));
      await tester.pumpAndSettle();
      expect(find.text('Fizetős OpenAI-generálás'), findsNothing);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    }
  });
}

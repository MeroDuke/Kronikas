import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_core/github_chronicle_remote.dart';
import 'package:kronikas_platform_probe/story_picker.dart';

import '../tool/story_picker_walkthrough.dart';

void main() {
  testWidgets(
    'Login demo can be cancelled and then opens the synthetic story list',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'kronikas-login-demo-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      await tester.pumpWidget(buildWalkthroughApp(directory, loginDemo: true));
      await tester.tap(find.text('Belépés GitHubbal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('DEMO-MESE'), findsOneWidget);
      await tester.tap(find.text('Mégse'));
      await tester.pumpAndSettle();
      expect(find.text('Teszt mese'), findsNothing);
      await tester.tap(find.text('Belépés GitHubbal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Jóváhagyás szimulálása'));
      await tester.pumpAndSettle();
      expect(find.text('Teszt mese'), findsOneWidget);
    },
  );

  testWidgets(
    'GitHub login opens the only available repository on its default branch',
    (tester) async {
      await tester.pumpWidget(
        StoryPickerApp(
          signIn: (_) async =>
              (token: 'ghu_fixture', repositories: ['example/stories']),
          load: (repository, branch, token) async {
            expect(repository, 'example/stories');
            expect(branch, isNull);
            expect(token, 'ghu_fixture');
            return (
              branch: 'stories',
              stories: <GitHubStory>[],
              open: (_) => throw StateError('Unexpected story'),
              openSync: (_) => throw StateError('Unexpected story'),
            );
          },
        ),
      );
      expect(find.text('GitHub-repó címe'), findsNothing);
      await tester.tap(find.text('Belépés GitHubbal'));
      await tester.pumpAndSettle();
      expect(find.text('Mesék · stories'), findsOneWidget);
    },
  );
}

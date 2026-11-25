import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_core/github_chronicle_remote.dart';
import 'package:kronikas_platform_probe/story_picker.dart';

void main() {
  testWidgets(
    'GitHub login opens a repository from the list on its default branch',
    (tester) async {
      await tester.pumpWidget(
        StoryPickerApp(
          signIn: () async =>
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
      await tester.tap(find.text('GitHub csatlakoztatása'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('example/stories'));
      await tester.pumpAndSettle();
      expect(find.text('Mesék · stories'), findsOneWidget);
    },
  );
}

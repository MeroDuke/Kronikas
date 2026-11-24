import 'package:flutter/widgets.dart';
import 'package:kronikas_core/kronikas_core.dart';
import 'package:kronikas_platform_probe/story_picker.dart';

void main() {
  runApp(
    StoryPickerApp(
      testForm: (address: 'example/stories', token: 'github_pat_synthetic'),
      load: (address, branch, token) async {
        if (address != 'example/stories' ||
            branch != null ||
            token != 'github_pat_synthetic') {
          throw const FormatException('Unexpected walkthrough input.');
        }
        return (
          branch: 'main',
          stories: const [
            (title: 'Teszt mese', directory: 'stories/test-mese'),
          ],
          open: (story) async {
            final start = DateTime.utc(2026, 11, 24, 18);
            return Chronicle()
              ..createAdventure(
                id: 'synthetic',
                title: story.title,
                description: 'Szintetikus próbatörténet.',
              )
              ..startSession('synthetic', id: 'first', startedAt: start)
              ..recordImprovisedEvent(
                'synthetic',
                'first',
                id: 'river',
                description: 'A csapat átkelt a folyón.',
              )
              ..closeSession(
                'synthetic',
                'first',
                start.add(const Duration(hours: 2)),
              );
          },
        );
      },
    ),
  );
}

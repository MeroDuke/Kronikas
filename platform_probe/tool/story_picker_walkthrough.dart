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
          open: (story) async => Chronicle()
            ..createAdventure(
              id: 'synthetic',
              title: story.title,
              description: 'Szintetikus próbatörténet.',
            ),
        );
      },
    ),
  );
}

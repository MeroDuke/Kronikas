import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronikas_platform_probe/story_document.dart';

void main() {
  test('reads the distributed Word sample with matching section order', () {
    final file = File('../templates/the-missing-crown.docx');
    final story = readStoryDocument('sample.docx', file.readAsBytesSync());
    expect(story.title, 'Az eltűnt korona');
    expect(story.sections.map((section) => section.kind), [
      StorySectionKind.introduction,
      StorySectionKind.scene,
      StorySectionKind.milestone,
      StorySectionKind.outcome,
      StorySectionKind.outcome,
      StorySectionKind.note,
      StorySectionKind.scene,
    ]);
    expect(story.sections[3].paragraphs, ['Eljutnak a régi vízimalomhoz.']);
    expect(story.sections.last.title, 'A régi vízimalom');
  });

  for (final extension in ['md', 'txt', 'docx']) {
    test('reads the distributed $extension template', () {
      final file = File('../templates/story-template.$extension');
      final story = readStoryDocument(file.path, file.readAsBytesSync());
      expect(story.title, '[A mese címe]');
      expect(
        story.sections.where(
          (section) => section.kind == StorySectionKind.outcome,
        ),
        hasLength(2),
      );
    });
  }

  test('preserves unrecognized text and invalid section nesting', () {
    final story = readStoryDocument(
      'story.md',
      utf8.encode(
        '# A mese\n## Mérföldkő – A nyom\nSzöveg.\n## Szereplők\nA kapitány.',
      ),
    );
    expect(
      story.sections.map((section) => section.kind),
      everyElement(StorySectionKind.other),
    );
    expect(story.sections.expand((section) => section.paragraphs), [
      'Mérföldkő – A nyom',
      'Szöveg.',
      'Szereplők',
      'A kapitány.',
    ]);
  });

  test('rejects empty and invalid files', () {
    expect(() => readStoryDocument('empty.txt', []), throwsFormatException);
    expect(() => readStoryDocument('invalid.docx', [1, 2, 3]), throwsException);
  });
}

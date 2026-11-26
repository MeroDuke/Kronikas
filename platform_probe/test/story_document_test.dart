import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
      StorySectionKind.summary,
    ]);
    expect(story.sections[3].paragraphs, ['Eljutnak a régi vízimalomhoz.']);
    expect(story.sections[6].title, 'A régi vízimalom');
  });

  for (final extension in ['md', 'txt', 'docx']) {
    test('reads the distributed $extension template', () {
      final file = File('../templates/story-template.$extension');
      final story = readStoryDocument(file.path, file.readAsBytesSync());
      expect(story.title, '[A mese címe]');
      expect(story.sections.last.kind, StorySectionKind.summary);
      expect(story.sections.last.paragraphs, [
        '[Írd le, hogyan zárul a mese.]',
      ]);
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
        'Krónikás-mese\n# A mese\n## Mérföldkő – A nyom\nSzöveg.\n## Szereplők\nA kapitány.',
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

  test('rejects ordinary documents across all supported formats', () {
    final xml = utf8.encode(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body><w:p><w:r><w:t>Bevásárlólista</w:t></w:r></w:p></w:body>'
      '</w:document>',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('word/document.xml', xml.length, xml));
    final files = {
      'list.txt': utf8.encode('Bevásárlólista\nAlma és tej'),
      'list.md': utf8.encode('# Bevásárlólista\n## Bevezetés\nAlma és tej'),
      'list.docx': ZipEncoder().encode(archive),
    };
    for (final file in files.entries) {
      expect(
        () => readStoryDocument(file.key, file.value),
        throwsA(isA<NotStoryDocument>()),
        reason: file.key,
      );
    }
  });

  test('rejects empty and invalid files', () {
    expect(
      () => readStoryDocument('empty.txt', []),
      throwsA(isA<NotStoryDocument>()),
    );
    expect(() => readStoryDocument('invalid.docx', [1, 2, 3]), throwsException);
  });
}

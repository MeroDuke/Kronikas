import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const storyFileLimit = 8 * 1024 * 1024;
const _xmlLimit = 2 * 1024 * 1024;

enum StorySectionKind {
  introduction('Bevezetés', 0),
  scene('Jelenet', 0),
  milestone('Mérföldkő', 1),
  outcome('Lehetséges kimenetel', 2),
  note('Mesélői jegyzet', 1),
  other('Egyéb szöveg', 0);

  const StorySectionKind(this.label, this.depth);
  final String label;
  final int depth;
}

final class StorySection {
  StorySection(this.kind, this.title);

  final StorySectionKind kind;
  final String title;
  final List<String> paragraphs = [];
}

typedef StoryDocument = ({String title, List<StorySection> sections});
typedef _Paragraph = ({String text, bool title, bool heading});

final class NotStoryDocument implements Exception {
  const NotStoryDocument();
}

StoryDocument readStoryDocument(String filename, List<int> bytes) {
  if (bytes.length > storyFileLimit) {
    throw const FormatException('Story file is too large.');
  }
  final separator = filename.lastIndexOf('.');
  final extension = separator < 0
      ? ''
      : filename.substring(separator + 1).toLowerCase();
  var paragraphs = switch (extension) {
    'docx' => _wordParagraphs(bytes),
    'md' || 'txt' => _textParagraphs(utf8.decode(bytes), extension == 'md'),
    _ => throw const FormatException('Unsupported story format.'),
  };
  final explicitlyMarked =
      paragraphs.firstOrNull?.text.toLowerCase() == 'krónikás-mese';
  if (explicitlyMarked) paragraphs = paragraphs.sublist(1);
  if (paragraphs.isEmpty) throw const NotStoryDocument();
  final hasTitle =
      paragraphs.first.title ||
      (!paragraphs.first.heading && extension == 'txt');
  final sections = <StorySection>[];
  StorySection? current;
  var hasScene = false;
  var hasMilestone = false;
  for (final paragraph in paragraphs.skip(hasTitle ? 1 : 0)) {
    final marker = paragraph.heading ? _marker(paragraph.text) : null;
    if (marker != null) {
      final (kind, title) = marker;
      final valid = switch (kind) {
        StorySectionKind.milestone => hasScene,
        StorySectionKind.outcome => hasMilestone,
        _ => true,
      };
      if (valid) {
        switch (kind) {
          case StorySectionKind.scene:
            hasScene = true;
            hasMilestone = false;
          case StorySectionKind.milestone:
            hasMilestone = true;
          case StorySectionKind.introduction:
            hasScene = false;
            hasMilestone = false;
          case StorySectionKind.note:
          case StorySectionKind.outcome:
          case StorySectionKind.other:
            break;
        }
        current = StorySection(kind, title);
        sections.add(current);
        continue;
      }
    }
    if (paragraph.heading || current == null) {
      current = StorySection(StorySectionKind.other, '');
      sections.add(current);
    }
    current.paragraphs.add(paragraph.text);
  }
  if (!explicitlyMarked &&
      !sections.any((section) => section.kind == StorySectionKind.milestone)) {
    throw const NotStoryDocument();
  }
  return (
    title: hasTitle ? paragraphs.first.text : filename.substring(0, separator),
    sections: sections,
  );
}

(StorySectionKind, String)? _marker(String text) {
  final match = RegExp(r'^(.+?)\s*[-–—:]\s*(.+)$').firstMatch(text);
  final label = (match?.group(1) ?? text).trim().toLowerCase();
  for (final kind in StorySectionKind.values) {
    if (kind == StorySectionKind.other || kind.label.toLowerCase() != label)
      continue;
    final title = match?.group(2)?.trim() ?? '';
    if (title.isNotEmpty ||
        kind == StorySectionKind.introduction ||
        kind == StorySectionKind.note) {
      return (kind, title);
    }
  }
  return null;
}

List<_Paragraph> _textParagraphs(String text, bool markdown) {
  final result = <_Paragraph>[];
  for (final line in const LineSplitter().convert(text)) {
    final value = line.trim();
    if (value.isEmpty) continue;
    final heading = markdown
        ? RegExp(r'^(#{1,6})[ \t]+(.+)$').firstMatch(value)
        : null;
    result.add((
      text: heading?.group(2)?.trim() ?? value,
      title: heading?.group(1) == '#',
      heading: heading != null || (!markdown && _marker(value) != null),
    ));
  }
  return result;
}

List<_Paragraph> _wordParagraphs(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, throwOnError: true);
  final entry = archive.findFile('word/document.xml');
  if (entry == null || !entry.isFile || entry.size > _xmlLimit) {
    throw const FormatException('Invalid Word document.');
  }
  final output = _BoundedOutput();
  entry.writeContent(output);
  final xml = XmlDocument.parse(utf8.decode(output.getBytes()));
  const word = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  final body = xml.rootElement.getElement('body', namespace: word);
  if (body == null) throw const FormatException('Missing Word document body.');
  final result = <_Paragraph>[];
  for (final paragraph in body.findAllElements('p', namespace: word)) {
    final style = paragraph
        .getElement('pPr', namespace: word)
        ?.getElement('pStyle', namespace: word)
        ?.getAttribute('val', namespace: word);
    final text = paragraph.descendants
        .whereType<XmlElement>()
        .where(
          (node) =>
              node.namespaceUri == word &&
              const {'t', 'tab', 'br', 'cr'}.contains(node.name.local),
        )
        .map(
          (node) => switch (node.name.local) {
            't' => node.innerText,
            'tab' => '\t',
            _ => '\n',
          },
        )
        .join()
        .trim();
    if (text.isNotEmpty) {
      result.add((
        text: text,
        title: style == 'Title',
        heading: style?.startsWith('Heading') ?? false,
      ));
    }
  }
  return result;
}

final class _BoundedOutput extends OutputMemoryStream {
  void _check(int count) {
    if (length + count > _xmlLimit) {
      throw const FormatException('Word document content is too large.');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }

  @override
  void reserve(int total) {
    if (total > _xmlLimit)
      throw const FormatException('Word document content is too large.');
    super.reserve(total);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}

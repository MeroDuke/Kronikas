import 'dart:convert';

import 'local_chronicle_store.dart';
import 'src/chronicle_json.dart';

/// A catalog lists revisions without fetching story contents.
abstract interface class StoryStorage {
  String get identity;
  Future<Map<String, String>> listVersions();
  Future<String> read(String id, String version);
  Future<String?> write(String id, String? expectedVersion, String snapshot);
}

enum StorySyncResult { complete, conflict, pending }

/// Sync metadata and local story content are committed together.
final class StoryStorageSync {
  StoryStorageSync(this.local, this.remote);

  final LocalChronicleStore local;
  final StoryStorage remote;
  Future<StorySyncResult> _queue = Future.value(StorySyncResult.complete);

  Future<StorySyncResult> synchronize({bool download = true}) {
    final task = _queue.then((_) => _synchronize(download));
    _queue = task;
    return task;
  }

  Future<StorySyncResult> _synchronize(bool download) async {
    try {
      final current = local.readRevision();
      if (current.sync['storyStorage'] case final String identity) {
        if (identity != remote.identity) return StorySyncResult.pending;
      }
      final versions = Map<String, String>.from(
        current.sync['storyVersions'] as Map? ?? const {},
      );
      final savedRevisions = Map<String, int>.from(
        current.sync['storyRevisions'] as Map? ?? const {},
      );
      final catalog = await remote.listVersions();
      final document = _document(encodeChronicle(current.chronicle));
      final stories = _stories(document);
      final campaigns = _campaigns(document);
      var result = StorySyncResult.complete;
      for (final id in {...stories.keys, if (download) ...catalog.keys}) {
        final base = versions[id];
        final head = catalog[id];
        final localStory = stories[id];
        final snapshot = localStory == null
            ? null
            : _snapshot(localStory, campaigns);
        final saved = savedRevisions[id];
        final previous = saved == null ? null : _storyAt(local, saved, id);
        final dirty = snapshot != null && snapshot != previous;
        if (head != base) {
          if (!download && !dirty) continue;
          if (head == null) {
            result = StorySyncResult.conflict;
            continue;
          }
          final incoming = await remote.read(id, head);
          final remoteDocument = _document(incoming);
          final remoteStories = _stories(remoteDocument);
          if (remoteStories.length != 1 || !remoteStories.containsKey(id)) {
            throw const FormatException('Story does not match its file ID.');
          }
          final remoteCampaigns = _campaigns(remoteDocument);
          final remoteStory = remoteStories[id]!;
          final canonical = _snapshot(remoteStory, remoteCampaigns);
          if ((dirty && snapshot != canonical) ||
              remoteCampaigns.entries.any(
                (entry) =>
                    campaigns.containsKey(entry.key) &&
                    jsonEncode(campaigns[entry.key]) != jsonEncode(entry.value),
              )) {
            result = StorySyncResult.conflict;
            continue;
          }
          if (!download && snapshot != canonical) continue;
          if (snapshot != canonical) {
            stories[id] = remoteStory;
            campaigns.addAll(remoteCampaigns);
          }
          versions[id] = head;
          savedRevisions[id] = current.revision + 1;
        } else if (dirty) {
          final written = await remote.write(id, head, snapshot);
          if (written == null) {
            result = StorySyncResult.conflict;
            continue;
          }
          // Record successful writes even if a newer edit happened in flight.
          // The uploaded revision remains the comparison base for that edit.
          final latest = local.readRevision();
          final uploadedVersions = Map<String, String>.from(
            latest.sync['storyVersions'] as Map? ?? const {},
          )..[id] = written;
          final uploadedRevisions = Map<String, int>.from(
            latest.sync['storyRevisions'] as Map? ?? const {},
          )..[id] = current.revision;
          if (!local.replaceIfCurrent(
            latest.revision,
            sync: {
              ...latest.sync,
              'storyStorage': remote.identity,
              'storyVersions': uploadedVersions,
              'storyRevisions': uploadedRevisions,
            },
          )) {
            return StorySyncResult.pending;
          }
          // Re-read the catalog and apply any downloads to the latest local
          // revision. There are at most as many repeats as successful writes.
          return await _synchronize(download);
        }
      }
      if (jsonEncode(versions) == jsonEncode(current.sync['storyVersions']) &&
          jsonEncode(savedRevisions) ==
              jsonEncode(current.sync['storyRevisions'])) {
        return result;
      }
      final updated = decodeChronicle(
        jsonEncode({
          ...document,
          'adventures': stories.values.toList(),
          'campaigns': campaigns.values.toList(),
        }),
      );
      final committed = local.replaceIfCurrent(
        current.revision,
        sync: {
          ...current.sync,
          'storyStorage': remote.identity,
          'storyVersions': versions,
          'storyRevisions': savedRevisions,
        },
        snapshot: encodeChronicle(updated) == encodeChronicle(current.chronicle)
            ? null
            : updated,
      );
      return committed ? result : StorySyncResult.pending;
    } on Exception {
      return StorySyncResult.pending;
    }
  }
}

Map<String, dynamic> _document(String snapshot) =>
    jsonDecode(snapshot) as Map<String, dynamic>;

Map<String, Map<String, dynamic>> _entries(Object? items) => {
  for (final item in (items as List).cast<Map<String, dynamic>>())
    item['id'] as String: item,
};

Map<String, Map<String, dynamic>> _stories(Map<String, dynamic> document) =>
    _entries(document['adventures']);

Map<String, Map<String, dynamic>> _campaigns(Map<String, dynamic> document) =>
    _entries(document['campaigns']);

String? _storyAt(LocalChronicleStore local, int revision, String id) {
  final document = _document(encodeChronicle(local.openRevision(revision)));
  final story = _stories(document)[id];
  return story == null ? null : _snapshot(story, _campaigns(document));
}

String _snapshot(
  Map<String, dynamic> story,
  Map<String, Map<String, dynamic>> campaigns,
) => encodeChronicle(
  decodeChronicle(
    jsonEncode({
      'schemaVersion': 1,
      'adventures': [story],
      'campaigns': [
        if (story['campaignId'] case final String id) campaigns[id],
      ],
    }),
  ),
);

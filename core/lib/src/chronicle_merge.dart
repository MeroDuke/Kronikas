import 'dart:convert';

import '../kronikas_core.dart';
import 'chronicle_json.dart';

typedef _Document = Map<String, Object?>;

const _absent = Object();

/// JSON values for a conflict. Null denotes an absent field or record.
typedef MergeConflict = ({List<String> path, String? local, String? remote});

typedef ConflictResolver = String? Function(MergeConflict conflict);

/// Combines independent changes to snapshots with a known common ancestor.
/// A null result leaves both original snapshots available for resolution.
Chronicle? mergeChronicles(
  Chronicle base,
  Chronicle local,
  Chronicle remote, {
  ConflictResolver? resolve,
}) {
  _Document document(Chronicle value) =>
      jsonDecode(encodeChronicle(value)) as _Document;

  try {
    final merged = _merge(
      document(base),
      document(local),
      document(remote),
      [],
      resolve,
    );
    return decodeChronicle(jsonEncode(merged));
  } on _Collision {
    return null;
  } on FormatException {
    // Independently valid edits may break a domain invariant in combination.
    return null;
  }
}

Object? _merge(
  Object? base,
  Object? local,
  Object? remote,
  List<String> path,
  ConflictResolver? resolve,
) {
  if (_same(local, remote) || _same(base, remote)) return local;
  if (_same(base, local)) return remote;

  if (base is _Document && local is _Document && remote is _Document) {
    return _mergeFields(base, local, remote, path, resolve);
  }
  if (base is List<Object?> &&
      local is List<Object?> &&
      remote is List<Object?>) {
    return _mergeRecords(base, local, remote, path, resolve);
  }
  if (resolve == null) throw const _Collision();
  String? encode(Object? value) =>
      identical(value, _absent) ? null : jsonEncode(value);
  final selected = resolve((
    path: List.unmodifiable(path),
    local: encode(local),
    remote: encode(remote),
  ));
  return selected == null ? _absent : jsonDecode(selected);
}

_Document _mergeFields(
  _Document base,
  _Document local,
  _Document remote,
  List<String> path,
  ConflictResolver? resolve,
) {
  final result = <String, Object?>{};
  for (final key in {...base.keys, ...local.keys, ...remote.keys}) {
    final value = _merge(
      base.containsKey(key) ? base[key] : _absent,
      local.containsKey(key) ? local[key] : _absent,
      remote.containsKey(key) ? remote[key] : _absent,
      [...path, key],
      resolve,
    );
    if (!identical(value, _absent)) result[key] = value;
  }
  return result;
}

List<Object?> _mergeRecords(
  List<Object?> base,
  List<Object?> local,
  List<Object?> remote,
  List<String> path,
  ConflictResolver? resolve,
) {
  _Document indexed(List<Object?> items) => {
    for (final item in items.cast<_Document>()) item['id'] as String: item,
  };

  final original = indexed(base);
  final left = indexed(local);
  final right = indexed(remote);
  Set<Object> appendedMilestones(_Document side, _Document other) => {
    for (final entry in side.entries)
      if (!original.containsKey(entry.key) && !other.containsKey(entry.key))
        if ((entry.value as _Document)['milestoneId'] case final String id) id,
  };

  if (appendedMilestones(
    left,
    right,
  ).intersection(appendedMilestones(right, left)).isNotEmpty) {
    // Both clients changed the same milestone by appending history.
    throw const _Collision();
  }
  final merged = _mergeFields(original, left, right, path, resolve);
  // Keep existing order and append remote additions before local additions.
  // Preserving both inputs' relative order avoids replaying history out of order.
  if (merged.values.any((item) => item is! _Document)) throw const _Collision();
  final order = {
    ...original.keys,
    ...right.keys,
    ...left.keys,
  }.where(merged.containsKey).toList();
  for (final side in [left, right]) {
    final kept = side.keys.where(merged.containsKey);
    if (!_same(kept.toList(), order.where(side.containsKey).toList())) {
      throw const _Collision();
    }
  }
  if (order.any((key) => (merged[key] as _Document)['id'] != key)) {
    throw const _Collision();
  }
  return [for (final key in order) merged[key]];
}

bool _same(Object? a, Object? b) {
  if (identical(a, b) || a == b) return true;
  if (a is _Document && b is _Document) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  if (a is List<Object?> && b is List<Object?>) {
    return a.length == b.length &&
        Iterable.generate(a.length).every((index) => _same(a[index], b[index]));
  }
  return false;
}

final class _Collision implements Exception {
  const _Collision();
}

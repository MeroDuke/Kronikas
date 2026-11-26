import 'dart:io';

enum DebugEvent {
  app_started,
  settings_opened,
  story_picker_opened,
  story_file_selected,
  story_opened,
  story_rejected,
  story_open_failed,
  adventure_opened,
  adventure_form_opened,
  milestone_form_opened,
  form_cancelled,
  field_edited,
  adventure_save_requested,
  adventure_saved,
  adventure_save_failed,
  session_start_requested,
  session_close_requested,
  session_change_saved,
  session_change_failed,
  outcome_editor_opened,
  outcome_save_requested,
  note_editor_opened,
  note_save_requested,
  event_editor_opened,
  event_save_requested,
  story_list_opened,
  session_history_toggled,
  discord_settings_saved,
  discord_settings_removed,
  discord_settings_save_requested,
  discord_settings_remove_requested,
  discord_settings_failed,
  openai_key_save_requested,
  openai_key_remove_requested,
  openai_key_saved,
  openai_key_removed,
  openai_key_failed,
  introduction_share_opened,
  summary_share_opened,
  ai_option_changed,
  ai_approved,
  ai_declined,
  ai_generation_started,
  ai_generation_completed,
  ai_generation_failed,
  discord_send_requested,
  discord_send_started,
  discord_sent,
  discord_rejected,
  discord_rate_limited,
  discord_delivery_uncertain,
  sync_started,
  sync_completed,
  sync_conflict,
  sync_pending,
  route_closed,
  logging_enabled,
  log_exported;

  String get component => switch (this) {
    app_started => 'app',
    logging_enabled || log_exported => 'logger',
    story_opened || story_rejected || story_open_failed => 'document',
    adventure_saved ||
    adventure_save_failed ||
    session_change_saved ||
    session_change_failed => 'local_storage',
    discord_settings_saved ||
    discord_settings_removed ||
    discord_settings_failed ||
    openai_key_saved ||
    openai_key_removed ||
    openai_key_failed => 'settings',
    ai_generation_started ||
    ai_generation_completed ||
    ai_generation_failed => 'openai',
    discord_send_started ||
    discord_sent ||
    discord_rejected ||
    discord_rate_limited ||
    discord_delivery_uncertain => 'discord',
    sync_started || sync_completed || sync_conflict || sync_pending => 'sync',
    _ => 'flutter_ui',
  };
}

final class DebugLog {
  DebugLog(this.directory, {File? enabledMarker, this.maxBytes = 128 * 1024})
    : _enabledMarker =
          enabledMarker ?? File.fromUri(directory.uri.resolve('enabled')) {
    enabled = _enabledMarker.existsSync();
    pruneExpired();
  }

  static DebugLog? current;
  final Directory directory;
  final int maxBytes;
  final File _enabledMarker;
  late bool enabled;
  bool writeFailed = false;
  File? _activeFile;
  DateTime? _lastPrune;
  static const retention = Duration(days: 14);
  static const _legacyNames = ['debug.previous.log', 'debug.log'];
  static final _logName = RegExp(
    r'^debug-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}(?:-\d+)?\.log$',
  );

  File _file(String name) => File.fromUri(directory.uri.resolve(name));

  static String timestamp(DateTime time) => time
      .toUtc()
      .toIso8601String()
      .substring(0, 19)
      .replaceFirst('T', '_')
      .replaceAll(':', '-');

  String _name(File file) => file.uri.pathSegments.last;

  List<File> _logFiles() {
    if (!directory.existsSync()) return [];
    final files = [
      for (final name in _legacyNames)
        if (_file(name).existsSync()) _file(name),
    ];
    final dated =
        directory
            .listSync(followLinks: false)
            .whereType<File>()
            .where((file) => _logName.hasMatch(_name(file)))
            .toList()
          ..sort(
            (a, b) =>
                _name(a).split('.').first.compareTo(_name(b).split('.').first),
          );
    return [...files, ...dated];
  }

  File _newLogFile(DateTime now) {
    directory.createSync(recursive: true);
    final stem = 'debug-${timestamp(now)}';
    var file = _file('$stem.log');
    var suffix = 0;
    while (file.existsSync()) {
      suffix++;
      file = _file('$stem-${suffix.toString().padLeft(4, '0')}.log');
    }
    file.createSync(exclusive: true);
    return file;
  }

  DateTime _fileDate(File file) {
    final name = _name(file);
    if (!_logName.hasMatch(name)) return file.lastModifiedSync().toUtc();
    final date = name.substring(6, 16);
    final time = name.substring(17, 25).replaceAll('-', ':');
    return DateTime.tryParse('${date}T${time}Z') ??
        file.lastModifiedSync().toUtc();
  }

  void pruneExpired({DateTime? now}) {
    final time = (now ?? DateTime.now()).toUtc();
    _lastPrune = time;
    final cutoff = time.subtract(retention);
    try {
      final files = _logFiles();
      final legacyFolder = _enabledMarker.parent;
      if (legacyFolder.absolute.uri != directory.absolute.uri) {
        files.addAll(
          [
            for (final name in _legacyNames)
              File.fromUri(legacyFolder.uri.resolve(name)),
          ].where((file) => file.existsSync()),
        );
      }
      for (final file in files) {
        try {
          if (_fileDate(file).isAfter(cutoff)) continue;
          file.deleteSync();
          if (_activeFile?.uri == file.uri) _activeFile = null;
        } on FileSystemException {
          // A locked or already removed file can wait for the next sweep.
        }
      }
    } on FileSystemException {
      // Diagnostics housekeeping must not prevent startup or other actions.
    }
  }

  List<File> filesForExport() {
    pruneExpired();
    return _logFiles().reversed.toList();
  }

  void setEnabled(bool value) {
    if (value == enabled) return;
    final marker = _enabledMarker;
    if (value) {
      _activeFile ??= _newLogFile(DateTime.now());
      marker.parent.createSync(recursive: true);
      marker.createSync();
    } else {
      if (marker.existsSync()) marker.deleteSync();
    }
    enabled = value;
    writeFailed = false;
    if (value) record(DebugEvent.logging_enabled);
  }

  void record(DebugEvent event) {
    if (!enabled) return;
    try {
      final now = DateTime.now().toUtc();
      if (_lastPrune == null ||
          now.difference(_lastPrune!) >= const Duration(hours: 1)) {
        pruneExpired(now: now);
      }
      var file = _activeFile ??= _newLogFile(now);
      final line =
          '${now.toIso8601String()} [${event.component}] ${event.name}\n';
      if (file.existsSync() && file.lengthSync() + line.length > maxBytes) {
        file = _activeFile = _newLogFile(now);
      }
      file.writeAsStringSync(line, mode: FileMode.append);
      writeFailed = false;
    } on FileSystemException {
      writeFailed = true;
    }
  }

  String read() =>
      filesForExport().reversed.map((file) => file.readAsStringSync()).join();
}

void debugEvent(DebugEvent event) => DebugLog.current?.record(event);

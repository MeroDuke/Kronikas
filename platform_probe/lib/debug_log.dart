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
  DebugLog(this.directory, {this.maxBytes = 128 * 1024})
    : enabled = File.fromUri(directory.uri.resolve('enabled')).existsSync();

  static DebugLog? current;
  final Directory directory;
  final int maxBytes;
  bool enabled;

  File _file(String name) => File.fromUri(directory.uri.resolve(name));

  void setEnabled(bool value) {
    if (value == enabled) return;
    final marker = _file('enabled');
    if (value) {
      directory.createSync(recursive: true);
      marker.createSync();
    } else {
      if (marker.existsSync()) marker.deleteSync();
    }
    enabled = value;
    if (value) record(DebugEvent.logging_enabled);
  }

  void record(DebugEvent event) {
    if (!enabled) return;
    try {
      final file = _file('debug.log');
      final line =
          '${DateTime.now().toUtc().toIso8601String()} [${event.component}] ${event.name}\n';
      if (file.existsSync() && file.lengthSync() + line.length > maxBytes) {
        file.renameSync(_file('debug.previous.log').path);
      }
      file.writeAsStringSync(line, mode: FileMode.append);
    } on FileSystemException {
      // Diagnostics must not prevent the underlying action.
    }
  }

  String read() => ['debug.previous.log', 'debug.log']
      .map(_file)
      .where((file) => file.existsSync())
      .map((file) => file.readAsStringSync())
      .join();
}

void debugEvent(DebugEvent event) => DebugLog.current?.record(event);

import 'package:shared_preferences/shared_preferences.dart';

const _boolKeys = {'loose_tasks_first', 'countdowns_first'};
const _listKeys = {
  'hidden_todo_collections',
  'journal_operation_chain',
  'calendar_seen_alerts',
};
const _stringKeys = {
  'journal_collection_sort',
  'journal_entry_sort',
  'last_module',
  'last_journal_collection',
  'journal_page_style',
  'journal_image_style',
};

Map<String, dynamic> backupPreferences(SharedPreferences prefs) => {
  for (final key in {..._boolKeys, ..._listKeys, ..._stringKeys})
    if (prefs.containsKey(key)) key: prefs.get(key),
};

/// Validate the entire configuration before replacing any business data.
Map<String, dynamic>? parseBackupPreferences(dynamic raw) {
  if (raw == null) return null; // Older backups preserve current preferences.
  if (raw is! Map) throw const FormatException('Invalid backup preferences');
  final parsed = <String, dynamic>{};
  for (final key in {..._boolKeys, ..._listKeys, ..._stringKeys}) {
    if (!raw.containsKey(key)) continue;
    final value = raw[key];
    if ((_boolKeys.contains(key) && value is! bool) ||
        (_stringKeys.contains(key) && value is! String) ||
        (_listKeys.contains(key) &&
            (value is! List || value.any((v) => v is! String)))) {
      throw FormatException('Invalid preference: $key');
    }
    parsed[key] = value;
  }
  return parsed;
}

Future<void> restoreBackupPreferences(
  SharedPreferences prefs,
  Map<String, dynamic> values,
) async {
  for (final entry in values.entries) {
    final value = entry.value;
    final saved = value is bool
        ? await prefs.setBool(entry.key, value)
        : value is String
        ? await prefs.setString(entry.key, value)
        : await prefs.setStringList(entry.key, (value as List).cast<String>());
    if (!saved) throw StateError('Cannot restore ${entry.key}');
  }
}

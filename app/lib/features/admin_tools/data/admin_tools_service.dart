import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AdminToolsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> weeklyMasterlist() async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>('admin_weekly_masterlist');
    return value
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  /// Current values of the time settings, keyed by setting name (`HH:MM`).
  Future<Map<String, String>> timeSettings() async {
    _requireConfigured();
    final rows = await _client
        .from('settings')
        .select('key, value')
        .inFilter('key', timeSettingKeys);
    return {
      for (final row in rows)
        if (row['value'] is String) row['key'] as String: row['value'] as String,
    };
  }

  /// Minutes between the first and second "not ended" reminder, or null.
  Future<int?> reminderRepeatMinutes() async {
    _requireConfigured();
    final rows = await _client
        .from('settings')
        .select('value')
        .eq('key', 'reminder_repeat_minutes');
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    return value is int ? value : null;
  }

  static const timeSettingKeys = [
    'scan_hours_start',
    'scan_hours_end',
    'reminder_time',
  ];

  Future<void> setSetting(String key, dynamic value) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'admin_set_setting',
      params: {'p_key': key, 'p_value': value},
    );
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}

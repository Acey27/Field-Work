import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AdminToolsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> addTimeRecord({
    required String workerId,
    required String fieldId,
    required String technicianId,
    required DateTime workDate,
    required DateTime timeIn,
    required DateTime timeOut,
    required String reason,
  }) async {
    _requireConfigured();
    return _client.rpc<Map<String, dynamic>>(
      'admin_add_time_record',
      params: {
        'p_worker_id': workerId,
        'p_field_id': fieldId,
        'p_technician_id': technicianId,
        'p_work_date': _date(workDate),
        'p_time_in': timeIn.toUtc().toIso8601String(),
        'p_time_out': timeOut.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

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

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

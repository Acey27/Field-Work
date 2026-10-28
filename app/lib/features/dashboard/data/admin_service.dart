import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AdminService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> todayFieldDays() async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>('admin_today_field_days');
    return _rows(value);
  }

  Future<Map<String, dynamic>> statistics() async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>('admin_statistics');
    return value;
  }

  Future<List<Map<String, dynamic>>> flaggedScans() async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>('admin_flagged_scans');
    return _rows(value);
  }

  Future<Map<String, dynamic>> endFieldDay({
    required String fieldDayId,
    required String reason,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'admin_end_field_day',
      params: {'p_field_day_id': fieldDayId, 'p_reason': reason},
    );
    return value;
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}

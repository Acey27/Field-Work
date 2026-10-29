import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/ph_time.dart';
import '../domain/admin_stats.dart';

class AdminService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> todayFieldDays() async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>('get_today_field_days');
    return _rows(value);
  }

  /// The technician's last scan of [workDate] (UTC), or null if none.
  Future<DateTime?> suggestEndTime({
    required String technicianId,
    required String workDate,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'suggest_end_time',
      params: {'p_technician_id': technicianId, 'p_work_date': workDate},
    );
    final time = value['time'] as String?;
    return time == null ? null : DateTime.parse(time).toUtc();
  }

  Future<TodayStats> statsToday() async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>('get_stats_today');
    return TodayStats.fromJson(value);
  }

  /// [weekStart] must be a Monday (Philippine date).
  Future<WeekStats> statsWeek(DateTime weekStart) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'get_stats_week',
      params: {'p_week_start': formatPhDate(weekStart)},
    );
    return WeekStats.fromJson(value);
  }

  Future<List<FlaggedItem>> flaggedItems(DateTime from, DateTime to) async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>(
      'get_flagged_items',
      params: {'p_from': formatPhDate(from), 'p_to': formatPhDate(to)},
    );
    return value
        .whereType<Map<String, dynamic>>()
        .map(FlaggedItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> endFieldDay({
    required String technicianId,
    required String workDate,
    required DateTime endedAt,
    required String reason,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'admin_end_field_day',
      params: {
        'p_technician_id': technicianId,
        'p_work_date': workDate,
        'p_ended_at': endedAt.toUtc().toIso8601String(),
        'p_reason': reason,
      },
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

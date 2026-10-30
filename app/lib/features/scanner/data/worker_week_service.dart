import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/ph_time.dart';

class WorkerWeek {
  const WorkerWeek({
    required this.workerId,
    required this.name,
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.totalMinutes,
    required this.presentDays,
  });

  factory WorkerWeek.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] as List<dynamic>? ?? const []);
    return WorkerWeek(
      workerId: json['worker_id'] as String,
      name: json['name'] as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map(
            (day) => (
              date: DateTime.parse(day['date'] as String),
              minutes: (day['minutes'] as num?)?.toInt(),
            ),
          )
          .toList(),
      totalMinutes: (json['total_minutes'] as num).toInt(),
      presentDays: (json['present_days'] as num).toInt(),
    );
  }

  final String workerId;
  final String name;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<({DateTime date, int? minutes})> days;
  final int totalMinutes;
  final int presentDays;
}

class WorkerWeekService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<WorkerWeek> load(String workerId) async {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
    final response = await _client.rpc<Map<String, dynamic>>(
      'get_worker_week',
      params: {'p_worker_id': workerId.trim()},
    );
    return WorkerWeek.fromJson(response);
  }
}

String workerWeekDayLabel(DateTime date, int? minutes, String notEnded) {
  if (minutes == null) return '-';
  if (minutes == 0) return notEnded;
  return formatMinutes(minutes);
}

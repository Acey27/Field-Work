import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/ph_time.dart';

/// One attendance session for the admin's day list (CONTRACT.md 4.8, 10.3).
class TimeRecord {
  const TimeRecord({
    required this.sessionId,
    required this.workerId,
    required this.workerName,
    required this.technicianCode,
    required this.technicianName,
    required this.fieldName,
    required this.workDate,
    required this.timeIn,
    required this.timeOut,
    required this.enteredByAdmin,
    required this.manualReason,
  });

  factory TimeRecord.fromJson(Map<String, dynamic> json) {
    return TimeRecord(
      sessionId: json['session_id'] as String,
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String? ?? '',
      technicianCode: json['technician_code'] as String? ?? '',
      technicianName: json['technician_name'] as String? ?? '',
      fieldName: json['field_name'] as String? ?? '',
      workDate: json['work_date'] as String,
      timeIn: DateTime.parse(json['time_in'] as String).toUtc(),
      timeOut: json['time_out'] == null
          ? null
          : DateTime.parse(json['time_out'] as String).toUtc(),
      enteredByAdmin: json['entered_by_admin'] == true,
      manualReason: json['manual_reason'] as String?,
    );
  }

  final String sessionId;
  final String workerId;
  final String workerName;
  final String technicianCode;
  final String technicianName;
  final String fieldName;
  final String workDate;
  final DateTime timeIn;
  final DateTime? timeOut;
  final bool enteredByAdmin;
  final String? manualReason;
}

class TimeRecordsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<TimeRecord>> forDate(DateTime phDate) async {
    _requireConfigured();
    final rows = await _client.rpc<List<dynamic>>(
      'get_sessions_for_date',
      params: {'p_date': formatPhDate(phDate)},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(TimeRecord.fromJson)
        .toList();
  }

  Future<void> add({
    required String workerId,
    required String fieldId,
    required String technicianId,
    required DateTime workDate,
    required DateTime timeIn,
    required DateTime timeOut,
    required String reason,
  }) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'admin_add_time_record',
      params: {
        'p_worker_id': workerId,
        'p_field_id': fieldId,
        'p_technician_id': technicianId,
        'p_work_date': formatPhDate(workDate),
        'p_time_in': timeIn.toUtc().toIso8601String(),
        'p_time_out': timeOut.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

  Future<void> fix({
    required String sessionId,
    required DateTime timeIn,
    required DateTime timeOut,
    required String reason,
  }) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'admin_fix_time_record',
      params: {
        'p_session_id': sessionId,
        'p_time_in': timeIn.toUtc().toIso8601String(),
        'p_time_out': timeOut.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class TechnicianService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listTechnicians() async {
    _requireConfigured();
    final rows = await _client
        .from('profiles')
        .select('id,code,full_name,email:username,active')
        .eq('role', 'technician')
        .order('full_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> listFields() async {
    final rows = await _client
        .from('fields')
        .select('id,name,active')
        .eq('active', true)
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> listAssignments() async {
    final rows = await _client
        .from('field_assignments')
        .select('technician_id,field_id,fields(name)')
        .isFilter('unassigned_at', null);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final rows = await _client
        .from('devices')
        .select('id,technician_id,label,status,registered_at')
        .order('registered_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> assignField({
    required String technicianId,
    required String fieldId,
  }) async {
    await _client
        .from('field_assignments')
        .update({'unassigned_at': DateTime.now().toUtc().toIso8601String()})
        .eq('technician_id', technicianId)
        .isFilter('unassigned_at', null);
    await _client.from('field_assignments').insert({
      'technician_id': technicianId,
      'field_id': fieldId,
      'assigned_by': _client.auth.currentUser!.id,
    });
  }

  Future<void> setDeviceStatus(String deviceId, String action) async {
    await _client.rpc<Map<String, dynamic>>(
      action,
      params: {'p_device_id': deviceId},
    );
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}

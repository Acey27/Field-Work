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
    // One database step: the old assignment is closed and the new one opened
    // together, so a technician never ends up with two fields or none.
    await _client.rpc<Map<String, dynamic>>(
      'admin_assign_field',
      params: {'p_technician_id': technicianId, 'p_field_id': fieldId},
    );
  }

  Future<void> setActive({
    required String technicianId,
    required bool active,
  }) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'admin_set_technician_active',
      params: {'p_technician_id': technicianId, 'p_active': active},
    );
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

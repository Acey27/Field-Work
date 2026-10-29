import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class FieldService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listFields() async {
    _requireConfigured();
    final rows = await _client
        .from('fields')
        .select('id,name,location,address,active,archived_at,created_at')
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createField({
    required String name,
    String? location,
    String? address,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'admin_create_field',
      params: {'p_name': name, 'p_location': location, 'p_address': address},
    );
    return value;
  }

  Future<void> updateField({
    required String fieldId,
    required String name,
    String? location,
    String? address,
  }) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'admin_update_field',
      params: {
        'p_field_id': fieldId,
        'p_name': name,
        'p_location': location,
        'p_address': address,
      },
    );
  }

  Future<void> setActive({
    required String fieldId,
    required bool active,
  }) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'admin_set_field_active',
      params: {'p_field_id': fieldId, 'p_active': active},
    );
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}

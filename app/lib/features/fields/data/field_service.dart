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

  // The answers are read as `dynamic` on purpose. Before migration 018 these
  // functions returned the table row type, which PostgREST may send as an
  // object or as a one-item list. A strict `Map` cast threw after the change
  // was already saved, so the screen showed an error and never reloaded.
  Future<Map<String, dynamic>> createField({
    required String name,
    String? location,
    String? address,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<dynamic>(
      'admin_create_field',
      params: {'p_name': name, 'p_location': location, 'p_address': address},
    );
    return _asMap(value);
  }

  Future<void> updateField({
    required String fieldId,
    required String name,
    String? location,
    String? address,
  }) async {
    _requireConfigured();
    await _client.rpc<dynamic>(
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
    await _client.rpc<dynamic>(
      'admin_set_field_active',
      params: {'p_field_id': fieldId, 'p_active': active},
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class WorkerService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listWorkers() async {
    _requireConfigured();
    final rows = await _client
        .from('workers')
        .select('id,name,cp_no,address,qr_check,active')
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createWorker({
    required String name,
    String? cpNo,
    String? address,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'admin_create_worker',
      params: {'p_name': name, 'p_cp_no': cpNo, 'p_address': address},
    );
    return value;
  }

  Future<Map<String, dynamic>> updateWorker({
    required String workerId,
    required String name,
    String? cpNo,
    String? address,
  }) async {
    _requireConfigured();
    return _client.rpc<Map<String, dynamic>>(
      'admin_update_worker',
      params: {
        'p_worker_id': workerId,
        'p_name': name,
        'p_cp_no': cpNo,
        'p_address': address,
      },
    );
  }

  Future<void> setActive({
    required String workerId,
    required bool active,
  }) async {
    _requireConfigured();
    await _client
        .from('workers')
        .update({
          'active': active,
          'deleted_at': active
              ? null
              : DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', workerId);
  }

  Future<Map<String, dynamic>> reissueCard(String workerId) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'reissue_card',
      params: {'p_worker_id': workerId},
    );
    return value;
  }

  Future<Map<String, dynamic>> importWorkers(
    List<Map<String, dynamic>> rows, {
    required bool commit,
  }) async {
    _requireConfigured();
    final value = await _client.rpc<Map<String, dynamic>>(
      'import_workers',
      params: {'p_rows': rows, 'p_commit': commit},
    );
    return value;
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}

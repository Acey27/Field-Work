import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final userId = response.user?.id;
    if (userId == null) throw const AuthException('E_FORBIDDEN');
    final profile = await _client
        .from('profiles')
        .select('role, active, must_change_password')
        .eq('id', userId)
        .single();
    if (profile['active'] != true) {
      throw const AuthException('E_ACCOUNT_DISABLED');
    }
    if (profile['must_change_password'] == true) {
      throw const AuthException('E_MUST_CHANGE_PASSWORD');
    }
    return profile['role'] as String;
  }
}

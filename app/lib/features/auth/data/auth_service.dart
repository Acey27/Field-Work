import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthState> signIn({
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
    final state = await _client.rpc<Map<String, dynamic>>('get_login_state');
    if (state.isEmpty) {
      throw const AuthException('E_ACCOUNT_DISABLED');
    }
    return AuthState(
      role: state['role'] as String,
      mustChangePassword: state['must_change_password'] == true,
    );
  }

  Future<void> completeFirstLogin(String newPassword) async {
    final response = await _client.functions.invoke(
      'complete_first_login',
      body: {'new_password': newPassword},
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final code = data is Map ? data['error'] : null;
      throw AuthException(code is String ? code : 'E_PASSWORD_UPDATE_FAILED');
    }
  }
}

class AuthState {
  const AuthState({required this.role, required this.mustChangePassword});

  final String role;
  final bool mustChangePassword;
}

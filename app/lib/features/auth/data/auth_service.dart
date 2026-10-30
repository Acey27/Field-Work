import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../core/supabase/login_notice.dart';
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
    AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid email or password') ||
          message == 'e_forbidden') {
        throw const AuthException('E_INVALID_LOGIN');
      }
      rethrow;
    }
    final userId = response.user?.id;
    if (userId == null) throw const AuthException('E_INVALID_LOGIN');
    late final Map<String, dynamic> state;
    try {
      state = await _client.rpc<Map<String, dynamic>>('get_login_state');
    } on Object catch (error, stackTrace) {
      debugPrint('get_login_state failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const AuthException('E_LOGIN_STATE_FAILED');
    }
    if (state.isEmpty) {
      throw const AuthException('E_ACCOUNT_DISABLED');
    }
    final role = state['role'];
    final mustChangePassword = state['must_change_password'];
    if (role is! String || mustChangePassword is! bool) {
      debugPrint('get_login_state returned an invalid profile payload: $state');
      throw const AuthException('E_LOGIN_STATE_FAILED');
    }
    return AuthState(role: role, mustChangePassword: mustChangePassword);
  }

  /// Ends the session on this device. Always clears it locally, even when the
  /// server cannot be reached; [notice] is shown on the login page.
  Future<void> signOut({String? notice}) async {
    if (notice != null) loginNotice.value = notice;
    if (!SupabaseConfig.isConfigured) return;
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } on Object catch (error) {
      debugPrint('sign out failed: $error');
    }
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

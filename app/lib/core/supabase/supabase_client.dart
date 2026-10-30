import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_notice.dart';
import 'session_refresh_client.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      httpClient: SessionRefreshClient(
        inner: http.Client(),
        refreshToken: _refreshToken,
        onSessionLost: _endSession,
      ),
    );
  }

  /// A new access token, or null when the session cannot be renewed any more
  /// (the refresh token is gone). A failed connection is rethrown: it says
  /// nothing about the session.
  static Future<String?> _refreshToken() async {
    try {
      final response = await Supabase.instance.client.auth.refreshSession();
      return response.session?.accessToken;
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException {
      return null;
    }
  }

  /// Forget the session on this device; the app then goes to the login page.
  static void _endSession() {
    loginNotice.value ??= sessionEndedNotice;
    Supabase.instance.client.auth
        .signOut(scope: SignOutScope.local)
        .catchError((Object _) {});
  }
}

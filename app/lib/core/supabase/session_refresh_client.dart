import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// True when a PostgREST / Supabase answer says the access token has expired
/// (`PGRST303`, "JWT expired").
bool isJwtExpiredResponse(int status, String body) =>
    status == 401 &&
    (body.contains('PGRST303') || body.contains('JWT expired'));

/// An HTTP client that survives an expired access token.
///
/// A token can run out while the browser tab or the laptop was asleep (timers
/// are paused, so the automatic refresh did not happen). The first request
/// after waking then fails with `PGRST303`. This client asks for a new token
/// and sends that request once more. When no new token can be had (the refresh
/// token is gone, for example because the account was turned off), it calls
/// [onSessionLost] so the app can return to the login page.
class SessionRefreshClient extends http.BaseClient {
  SessionRefreshClient({
    required this.inner,
    required this.refreshToken,
    required this.onSessionLost,
  });

  final http.Client inner;

  /// Returns a new access token, or null when the session cannot be renewed
  /// any more. Throws when that is not known (for example no connection).
  final Future<String?> Function() refreshToken;

  final void Function() onSessionLost;

  /// Requests that expire together share one refresh (a second refresh with
  /// the same refresh token would be refused).
  Future<String?>? _refreshing;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (response.statusCode != 401 || request is! http.Request) return response;

    // Read the answer to see why it is a 401, then hand the same bytes back.
    final bytes = await response.stream.toBytes();
    if (!isJwtExpiredResponse(401, utf8.decode(bytes, allowMalformed: true))) {
      return _replay(response, bytes);
    }

    final String? token;
    try {
      token = await _newToken();
    } on Object {
      // The refresh could not even be tried (no connection): leave the session
      // alone and let the caller see the original answer.
      return _replay(response, bytes);
    }
    if (token == null) {
      onSessionLost();
      return _replay(response, bytes);
    }
    final retry = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..headers['Authorization'] = 'Bearer $token'
      ..bodyBytes = request.bodyBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    return inner.send(retry);
  }

  Future<String?> _newToken() {
    final running = _refreshing;
    if (running != null) return running;
    final next = refreshToken();
    _refreshing = next;
    return next.whenComplete(() => _refreshing = null);
  }

  http.StreamedResponse _replay(
    http.StreamedResponse response,
    List<int> body,
  ) => http.StreamedResponse(
    http.ByteStream.fromBytes(body),
    response.statusCode,
    contentLength: body.length,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );

  @override
  void close() => inner.close();
}

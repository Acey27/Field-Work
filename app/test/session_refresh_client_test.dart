import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fieldwork_attendance/core/supabase/session_refresh_client.dart';

const _expired =
    '{"code":"PGRST303","details":null,"hint":null,"message":"JWT expired"}';

void main() {
  group('isJwtExpiredResponse', () {
    test('recognises the PostgREST answer for an expired token', () {
      expect(isJwtExpiredResponse(401, _expired), isTrue);
      expect(isJwtExpiredResponse(401, 'JWT expired'), isTrue);
    });

    test('ignores other statuses and other 401 answers', () {
      expect(isJwtExpiredResponse(200, _expired), isFalse);
      expect(isJwtExpiredResponse(401, '{"message":"E_FORBIDDEN"}'), isFalse);
      expect(isJwtExpiredResponse(403, _expired), isFalse);
    });
  });

  group('SessionRefreshClient', () {
    late List<http.Request> seen;
    late int refreshCalls;
    late int lost;

    /// The server accepts only the token `new`; the old one is expired.
    SessionRefreshClient clientWith({
      Future<String?> Function()? refresh,
      String expiredBody = _expired,
      int expiredStatus = 401,
    }) {
      seen = [];
      refreshCalls = 0;
      lost = 0;
      final inner = MockClient((request) async {
        seen.add(request);
        final ok = request.headers['Authorization'] == 'Bearer new';
        return ok
            ? http.Response('{"ok":true}', 200)
            : http.Response(expiredBody, expiredStatus);
      });
      return SessionRefreshClient(
        inner: inner,
        refreshToken:
            refresh ??
            () async {
              refreshCalls++;
              return 'new';
            },
        onSessionLost: () => lost++,
      );
    }

    Future<http.Response> post(SessionRefreshClient client) => client.post(
      Uri.parse('https://example.test/rest/v1/rpc/get_sessions_for_date'),
      headers: {'Authorization': 'Bearer old', 'apikey': 'key'},
      body: '{"p_date":"2026-10-31"}',
    );

    test(
      'an expired token is renewed and the request sent once more',
      () async {
        final response = await post(clientWith());
        expect(response.statusCode, 200);
        expect(response.body, '{"ok":true}');
        expect(refreshCalls, 1);
        expect(seen, hasLength(2));
        expect(seen.last.headers['Authorization'], 'Bearer new');
        // The same call, with the same body and the other headers.
        expect(seen.last.url, seen.first.url);
        expect(seen.last.body, '{"p_date":"2026-10-31"}');
        expect(seen.last.headers['apikey'], 'key');
        expect(lost, 0);
      },
    );

    test('requests that expire together share one renewal', () async {
      final client = clientWith();
      final answers = await Future.wait([post(client), post(client)]);
      expect(answers.map((r) => r.statusCode), [200, 200]);
      expect(refreshCalls, 1);
    });

    test(
      'a session that cannot be renewed is reported once per request',
      () async {
        final client = clientWith(refresh: () async => null);
        final response = await post(client);
        // The caller still sees the original answer, readable in full.
        expect(response.statusCode, 401);
        expect(
          (jsonDecode(response.body) as Map<String, dynamic>)['code'],
          'PGRST303',
        );
        expect(lost, 1);
        expect(seen, hasLength(1));
      },
    );

    test('no connection while renewing leaves the session alone', () async {
      final client = clientWith(
        refresh: () async => throw http.ClientException('offline'),
      );
      final response = await post(client);
      expect(response.statusCode, 401);
      expect(lost, 0);
    });

    test('another 401 answer passes through without a renewal', () async {
      final client = clientWith(expiredBody: '{"message":"E_FORBIDDEN"}');
      final response = await post(client);
      expect(response.statusCode, 401);
      expect(response.body, '{"message":"E_FORBIDDEN"}');
      expect(refreshCalls, 0);
      expect(lost, 0);
      expect(seen, hasLength(1));
    });

    test('a good answer is returned untouched', () async {
      final client = clientWith();
      final response = await client.post(
        Uri.parse('https://example.test/rest/v1/rpc/ping'),
        headers: {'Authorization': 'Bearer new'},
      );
      expect(response.statusCode, 200);
      expect(refreshCalls, 0);
      expect(seen, hasLength(1));
    });
  });
}

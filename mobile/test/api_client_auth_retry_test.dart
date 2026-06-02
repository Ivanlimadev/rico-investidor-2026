import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/network/api_exception.dart';

void main() {
  group('ApiClient unauthorized retry', () {
    test('retries once after 401 and refreshes session', () async {
      var authCalls = 0;
      var metaCalls = 0;
      var token = 'expired-token';

      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta/providers') {
            metaCalls += 1;
            if (metaCalls == 1) {
              return http.Response('{"detail":"Token expirado"}', 401);
            }
            return http.Response('{"rules":{}}', 200);
          }

          if (request.url.path == '/v1/auth/anonymous') {
            authCalls += 1;
            token = 'fresh-token';
            return http.Response(
              jsonEncode({'access_token': token, 'expires_in': 3600}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('not found', 404);
        }),
        authHeaderProvider: () => token,
        onUnauthorized: () async {
          token = '';
          token = 'fresh-token';
        },
      );

      final result = await client.getJson('/v1/meta/providers', fromJson: (json) => json);

      expect(result, {'rules': {}});
      expect(metaCalls, 2);
      expect(authCalls, 0);
    });

    test('does not retry login failures', () async {
      var loginCalls = 0;

      final client = ApiClient(
        client: MockClient((request) async {
          loginCalls += 1;
          return http.Response('{"detail":"E-mail ou senha inválidos"}', 401);
        }),
      );

      await expectLater(
        client.postJson(
          '/v1/auth/login',
          body: {'email': 'a@b.com', 'password': 'wrong'},
          fromJson: (json) => json,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(loginCalls, 1);
    });
  });
}

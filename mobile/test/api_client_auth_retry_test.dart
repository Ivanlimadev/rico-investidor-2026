import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/network/api_exception.dart';

void main() {
  group('ApiClient retry', () {
    test('retries once after 401 and refreshes session', () async {
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
          return http.Response('not found', 404);
        }),
        authHeaderProvider: () => token,
        onUnauthorized: () async {
          token = 'fresh-token';
        },
      );

      final result = await client.getJson('/v1/meta/providers', fromJson: (json) => json);

      expect(result, {'rules': {}});
      expect(metaCalls, 2);
    });

    test('retries once after 429 rate limit', () async {
      var calls = 0;

      final client = ApiClient(
        client: MockClient((request) async {
          calls += 1;
          if (calls == 1) {
            return http.Response(
              '{"detail":"Muitas requisicoes - tente novamente em instantes."}',
              429,
            );
          }
          return http.Response('{"status":"ok"}', 200);
        }),
      );

      final result = await client.getJson('/v1/meta/providers', fromJson: (json) => json);

      expect(result, {'status': 'ok'});
      expect(calls, 2);
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

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rico_investidor/core/auth/session_expired_exception.dart';
import 'package:rico_investidor/core/network/api_client.dart';

void main() {
  test('propagates SessionExpiredException when handler throws it', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        return http.Response('{"detail":"Token expirado"}', 401);
      }),
      authHeaderProvider: () => 'stale-token',
      onUnauthorized: () async {
        throw const SessionExpiredException();
      },
    );

    await expectLater(
      client.getJson('/v1/meta/providers', fromJson: (json) => json),
      throwsA(isA<SessionExpiredException>()),
    );
  });
}

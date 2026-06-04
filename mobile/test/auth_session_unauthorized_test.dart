import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/auth/session_expired_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  test('refreshAfterUnauthorized throws for registered session', () async {
    final session = AuthSession();
    await session.setAccessToken('registered-token', registered: true);

    await expectLater(
      session.refreshAfterUnauthorized(),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(session.accessToken, isNull);
  });
}

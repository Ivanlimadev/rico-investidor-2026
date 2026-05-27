import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/config/api_config.dart';

void main() {
  group('ApiConfig.resolveBaseUrl', () {
    test('debug usa localhost no iOS/macOS', () {
      expect(
        ApiConfig.resolveBaseUrl(
          envBaseUrl: '',
          releaseMode: false,
          isWeb: false,
          isAndroid: false,
        ),
        'http://127.0.0.1:8000',
      );
    });

    test('debug usa 10.0.2.2 no Android', () {
      expect(
        ApiConfig.resolveBaseUrl(
          envBaseUrl: '',
          releaseMode: false,
          isWeb: false,
          isAndroid: true,
        ),
        'http://10.0.2.2:8000',
      );
    });

    test('release sem API_BASE_URL falha', () {
      expect(
        () => ApiConfig.resolveBaseUrl(
          envBaseUrl: '',
          releaseMode: true,
          isWeb: false,
          isAndroid: false,
        ),
        throwsA(isA<ApiConfigError>()),
      );
    });

    test('release rejeita http', () {
      expect(
        () => ApiConfig.resolveBaseUrl(
          envBaseUrl: 'http://api.example.com',
          releaseMode: true,
          isWeb: false,
          isAndroid: false,
        ),
        throwsA(
          predicate<ApiConfigError>((e) => e.message.contains('HTTPS')),
        ),
      );
    });

    test('release aceita https', () {
      expect(
        ApiConfig.resolveBaseUrl(
          envBaseUrl: 'https://api.example.com/v1/',
          releaseMode: true,
          isWeb: false,
          isAndroid: false,
        ),
        'https://api.example.com/v1',
      );
    });

    test('debug aceita http explícito', () {
      expect(
        ApiConfig.resolveBaseUrl(
          envBaseUrl: 'http://192.168.0.10:8000',
          releaseMode: false,
          isWeb: false,
          isAndroid: true,
        ),
        'http://192.168.0.10:8000',
      );
    });
  });
}

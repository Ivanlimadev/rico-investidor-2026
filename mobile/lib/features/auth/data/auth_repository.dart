import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/network/api_exception.dart';

class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<Map<String, dynamic>> me() {
    return _client.getJson('/v1/auth/me', fromJson: (json) => json);
  }

  Future<void> login({required String email, required String password}) async {
    final token = await _exchangeCredentials(
      path: '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    await authSession.setAccessToken(token);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final token = await _exchangeCredentials(
      path: '/v1/auth/register',
      body: {'email': email, 'password': password, 'name': name},
    );
    await authSession.setAccessToken(token);
  }

  Future<String> _exchangeCredentials({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final json = await _client.postJson(path, body: body, fromJson: (value) => value);
    final token = json['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Token de autenticação ausente');
    }
    return token;
  }
}

final authRepository = AuthRepository();

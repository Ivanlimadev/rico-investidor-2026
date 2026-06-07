import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/models/user_profile.dart';

class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<Map<String, dynamic>> me() {
    return _client.getJson('/v1/auth/me', fromJson: (json) => json);
  }

  Future<UserProfile> fetchProfile() async {
    final json = await me();
    return UserProfile(
      displayName: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Investidor',
      plan: SubscriptionPlan.free,
      email: json['email'] as String?,
      userId: json['id'] as String?,
      countryCode: (json['country_code'] as String?)?.trim().toUpperCase() ??
          (json['country'] as String?)?.trim().toUpperCase(),
      isAnonymous: json['is_anonymous'] as bool? ?? true,
    );
  }

  Future<void> logout() async {
    await authSession.clear();
    await authSession.ensureAuthenticated();
  }

  Future<void> login({required String email, required String password}) async {
    final token = await _exchangeCredentials(
      path: '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    await authSession.setAccessToken(token, registered: true);
  }

  Future<UserProfile> updateProfile({required String name}) async {
    final json = await _client.patchJson(
      '/v1/auth/me',
      body: {'name': name},
      fromJson: (value) => value,
    );
    return UserProfile(
      displayName: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Investidor',
      plan: SubscriptionPlan.free,
      email: json['email'] as String?,
      userId: json['id'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
    );
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
    await authSession.setAccessToken(token, registered: true);
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

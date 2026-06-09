import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/config/api_config.dart';
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
    return _profileFromJson(json);
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
    return _profileFromJson(json);
  }

  Future<UserProfile> uploadProfilePhoto(String filePath) async {
    final json = await _client.postMultipart(
      '/v1/auth/me/photo',
      fileField: 'file',
      filePath: filePath,
      fromJson: (value) => value,
    );
    return _profileFromJson(json);
  }

  Future<String> forgotPassword(String email) async {
    final json = await _client.postJson(
      '/v1/auth/forgot-password',
      body: {'email': email},
      fromJson: (value) => value,
    );
    return json['message']?.toString() ?? 'Check your email for reset instructions.';
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.postJson(
      '/v1/auth/reset-password',
      body: {'token': token, 'new_password': newPassword},
      fromJson: (value) => value,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.postJson(
      '/v1/auth/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      fromJson: (value) => value,
    );
  }

  Future<void> deleteAccount({String? password}) async {
    await _client.deleteJson(
      '/v1/auth/me',
      body: password == null ? null : {'password': password},
      fromJson: (value) => value,
    );
    await authSession.clear();
    await authSession.ensureAuthenticated();
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

  UserProfile _profileFromJson(Map<String, dynamic> json) {
    final rawPhoto = json['photo_url'] as String?;
    String? photoUrl;
    if (rawPhoto != null && rawPhoto.trim().isNotEmpty) {
      photoUrl = rawPhoto.startsWith('http')
          ? rawPhoto
          : '${ApiConfig.baseUrl}$rawPhoto';
    }

    return UserProfile(
      displayName: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Investidor',
      plan: SubscriptionPlan.free,
      photoUrl: photoUrl,
      email: json['email'] as String?,
      userId: json['id'] as String?,
      countryCode: (json['country_code'] as String?)?.trim().toUpperCase() ??
          (json['country'] as String?)?.trim().toUpperCase(),
      isAnonymous: json['is_anonymous'] as bool? ?? true,
    );
  }
}

final authRepository = AuthRepository();

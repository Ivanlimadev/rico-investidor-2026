import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/network/api_exception.dart';

const _tokenKey = 'auth_access_token';
const _deviceIdKey = 'auth_device_id';

class AuthSession {
  AuthSession({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _client;

  String? _accessToken;

  String? get accessToken => _accessToken;

  Future<void> ensureAuthenticated() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return;
    }

    final cached = await _storage.read(key: _tokenKey);
    if (cached != null && cached.isNotEmpty) {
      _accessToken = cached;
      return;
    }

    final deviceId = await _getOrCreateDeviceId();
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/anonymous');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 503) {
      // Backend sem AUTH_SECRET — API pública.
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Falha ao autenticar (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw ApiException(message, statusCode: response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Resposta de autenticação inválida');
    }

    final token = decoded['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Token de autenticação ausente');
    }

    _accessToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() async {
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.length >= 8) {
      return existing;
    }

    final created = 'rico-${DateTime.now().microsecondsSinceEpoch}';
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }
}

final authSession = AuthSession();

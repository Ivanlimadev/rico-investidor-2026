import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:rico_investidor/core/auth/secure_storage_config.dart';
import 'package:rico_investidor/core/auth/session_expired_exception.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/core/network/shared_http_client.dart';

const _tokenKey = 'auth_access_token';
const _deviceIdKey = 'auth_device_id';
const _sessionKindKey = 'auth_session_kind';
const _registeredKind = 'registered';
const _anonymousKind = 'anonymous';

typedef SessionRefreshListener = void Function();

class AuthSession {
  AuthSession({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? secureStorage,
        _client = client ?? sharedHttpClient;

  final FlutterSecureStorage _storage;
  final http.Client _client;

  String? _accessToken;

  SessionRefreshListener? onSessionRefreshed;
  SessionRefreshListener? onSessionExpired;

  String? get accessToken => _accessToken;

  bool get isRegisteredSession => _sessionKind == _registeredKind;

  String? _sessionKind;

  Future<void> ensureAuthenticated() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return;
    }

    final cached = await _storage.read(key: _tokenKey);
    if (cached != null && cached.isNotEmpty) {
      _accessToken = cached;
      _sessionKind = await _storage.read(key: _sessionKindKey) ?? _anonymousKind;
      return;
    }

    final deviceId = await _getOrCreateDeviceId();
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/anonymous');
    try {
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 503) {
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

      await setAccessToken(token, registered: false);
    } on SocketException {
      return;
    } on http.ClientException {
      return;
    } on TimeoutException {
      return;
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _sessionKind = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKindKey);
  }

  /// Limpa token inválido. Contas registradas exigem novo login; anônimas renovam JWT.
  Future<void> refreshAfterUnauthorized() async {
    final kind = _sessionKind ?? await _storage.read(key: _sessionKindKey);
    await clear();
    if (kind == _registeredKind) {
      onSessionExpired?.call();
      throw const SessionExpiredException();
    }
    await ensureAuthenticated();
    onSessionRefreshed?.call();
  }

  Future<void> setAccessToken(String token, {required bool registered}) async {
    _accessToken = token;
    _sessionKind = registered ? _registeredKind : _anonymousKind;
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _sessionKindKey, value: _sessionKind);
    } catch (_) {
      // macOS desktop: Keychain pode falhar sem entitlement; token em memória segue válido.
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.length >= 16) {
      return existing;
    }

    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final created = 'rico-${base64Url.encode(bytes).replaceAll('=', '')}';
    try {
      await _storage.write(key: _deviceIdKey, value: created);
    } catch (_) {}
    return created;
  }
}

final authSession = AuthSession();

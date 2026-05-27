import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/network/api_exception.dart';

typedef AuthHeaderProvider = String? Function();

class ApiClient {
  ApiClient({
    http.Client? client,
    AuthHeaderProvider? authHeaderProvider,
  })  : _client = client ?? http.Client(),
        _authHeaderProvider = authHeaderProvider ?? (() => authSession.accessToken);

  static const _timeout = Duration(seconds: 45);

  final http.Client _client;
  final AuthHeaderProvider _authHeaderProvider;

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _authHeaderProvider();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<T> postJson<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _client
        .post(
          uri(path),
          headers: _headers(json: true),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout);
    return _parse(response, fromJson);
  }

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _client.get(uri(path, query), headers: _headers()).timeout(_timeout);
    return _parse(response, fromJson);
  }

  Future<bool> checkHealth() async {
    final response = await _client.get(uri('/health'), headers: _headers()).timeout(_timeout);
    return response.statusCode == 200;
  }

  T _parse<T>(http.Response response, T Function(Map<String, dynamic>) fromJson) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Resposta inválida da API');
      }
      return fromJson(decoded);
    }

    var message = 'Erro ao buscar dados (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        message = body['detail'].toString();
      }
    } catch (_) {}

    throw ApiException(message, statusCode: response.statusCode);
  }
}

final apiClient = ApiClient();

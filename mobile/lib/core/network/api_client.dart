import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/network/api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Future<T> postJson<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _client.post(
      uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
    return _parse(response, fromJson);
  }

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _client.get(uri(path, query));
    return _parse(response, fromJson);
  }

  Future<bool> checkHealth() async {
    final response = await _client.get(uri('/health'));
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

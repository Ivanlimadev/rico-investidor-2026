import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/auth/session_expired_exception.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/core/network/shared_http_client.dart';

typedef AuthHeaderProvider = String? Function();
typedef UnauthorizedHandler = Future<void> Function();

class ApiClient {
  ApiClient({
    http.Client? client,
    AuthHeaderProvider? authHeaderProvider,
    UnauthorizedHandler? onUnauthorized,
  })  : _client = client ?? sharedHttpClient,
        _authHeaderProvider = authHeaderProvider ?? (() => authSession.accessToken),
        _onUnauthorized = onUnauthorized ?? authSession.refreshAfterUnauthorized;

  static const _timeout = Duration(seconds: 45);
  static const _rateLimitRetryDelay = Duration(milliseconds: 900);

  static const _noAuthRetryPaths = {
    '/v1/auth/login',
    '/v1/auth/register',
  };

  final http.Client _client;
  final AuthHeaderProvider _authHeaderProvider;
  final UnauthorizedHandler _onUnauthorized;

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
    return _execute(
      path: path,
      fromJson: fromJson,
      send: () => _client.post(
        uri(path),
        headers: _headers(json: true),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    required T Function(Map<String, dynamic>) fromJson,
    Duration? timeout,
  }) async {
    return _execute(
      path: path,
      fromJson: fromJson,
      timeout: timeout ?? _timeout,
      send: () => _client.get(uri(path, query), headers: _headers()),
    );
  }

  Future<T> putJson<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    return _execute(
      path: path,
      fromJson: fromJson,
      send: () => _client.put(
        uri(path),
        headers: _headers(json: true),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<T> patchJson<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    return _execute(
      path: path,
      fromJson: fromJson,
      send: () => _client.patch(
        uri(path),
        headers: _headers(json: true),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<T> postMultipart<T>(
    String path, {
    required String fileField,
    required String filePath,
    required T Function(Map<String, dynamic>) fromJson,
    String? filename,
  }) async {
    return _executeMultipart(
      path: path,
      fromJson: fromJson,
      build: () async {
        final request = http.MultipartRequest('POST', uri(path));
        final headers = _headers();
        request.headers.addAll(headers);
        request.files.add(
          await http.MultipartFile.fromPath(
            fileField,
            filePath,
            filename: filename ?? filePath.split(Platform.pathSeparator).last,
          ),
        );
        return request;
      },
    );
  }

  Future<T> deleteJson<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    return _execute(
      path: path,
      fromJson: fromJson,
      send: () => _client.delete(
        uri(path),
        headers: _headers(json: body != null),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<bool> checkHealth() async {
    final response = await _client
        .get(uri('/health'), headers: _headers())
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  }

  Future<T> _executeMultipart<T>({
    required String path,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<http.MultipartRequest> Function() build,
    bool unauthorizedRetried = false,
    bool rateLimitRetried = false,
  }) async {
    final request = await build();
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && !unauthorizedRetried && _shouldRetryUnauthorized(path)) {
      try {
        await _onUnauthorized();
      } on SessionExpiredException {
        rethrow;
      }
      return _executeMultipart(
        path: path,
        fromJson: fromJson,
        build: build,
        unauthorizedRetried: true,
        rateLimitRetried: rateLimitRetried,
      );
    }

    if (response.statusCode == 429 && !rateLimitRetried) {
      await Future<void>.delayed(_rateLimitRetryDelay);
      return _executeMultipart(
        path: path,
        fromJson: fromJson,
        build: build,
        unauthorizedRetried: unauthorizedRetried,
        rateLimitRetried: true,
      );
    }

    return _parse(response, fromJson);
  }

  Future<T> _execute<T>({
    required String path,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<http.Response> Function() send,
    Duration timeout = _timeout,
    bool unauthorizedRetried = false,
    bool rateLimitRetried = false,
  }) async {
    final response = await send().timeout(timeout);

    if (response.statusCode == 401 && !unauthorizedRetried && _shouldRetryUnauthorized(path)) {
      try {
        await _onUnauthorized();
      } on SessionExpiredException {
        rethrow;
      }
      return _execute(
        path: path,
        fromJson: fromJson,
        send: send,
        timeout: timeout,
        unauthorizedRetried: true,
        rateLimitRetried: rateLimitRetried,
      );
    }

    if (response.statusCode == 429 && !rateLimitRetried) {
      await Future<void>.delayed(_rateLimitRetryDelay);
      return _execute(
        path: path,
        fromJson: fromJson,
        send: send,
        timeout: timeout,
        unauthorizedRetried: unauthorizedRetried,
        rateLimitRetried: true,
      );
    }

    return _parse(response, fromJson);
  }

  bool _shouldRetryUnauthorized(String path) {
    return !_noAuthRetryPaths.contains(path);
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

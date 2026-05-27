import 'dart:io';

import 'package:flutter/foundation.dart';

/// URL base da API.
///
/// Dev (debug/profile): defaults HTTP locais.
/// Release: exige `--dart-define=API_BASE_URL=https://...`
class ApiConfigError implements Exception {
  ApiConfigError(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl => resolveBaseUrl(
        envBaseUrl: _envBaseUrl,
        releaseMode: kReleaseMode,
        isWeb: kIsWeb,
        isAndroid: !kIsWeb && Platform.isAndroid,
      );

  /// Lógica pura para validação em testes.
  static String resolveBaseUrl({
    required String envBaseUrl,
    required bool releaseMode,
    required bool isWeb,
    required bool isAndroid,
  }) {
    if (envBaseUrl.isNotEmpty) {
      return _normalizeAndValidate(envBaseUrl, requireHttps: releaseMode);
    }

    if (releaseMode) {
      throw ApiConfigError(
        'Release exige API_BASE_URL com HTTPS. '
        'Ex.: flutter build apk --dart-define=API_BASE_URL=https://api.seudominio.com',
      );
    }

    if (isWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static String _normalizeAndValidate(String raw, {required bool requireHttps}) {
    final normalized = raw.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ApiConfigError('API_BASE_URL inválida: $raw');
    }

    if (requireHttps && uri.scheme != 'https') {
      throw ApiConfigError(
        'Release exige HTTPS na API (recebido "${uri.scheme}"). '
        'Use API_BASE_URL=https://...',
      );
    }

    if (!requireHttps && uri.scheme != 'http' && uri.scheme != 'https') {
      throw ApiConfigError('API_BASE_URL deve usar http ou https (recebido "${uri.scheme}").');
    }

    return normalized;
  }
}

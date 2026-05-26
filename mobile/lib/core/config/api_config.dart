import 'dart:io';

import 'package:flutter/foundation.dart';

/// URL base da API Python local.
///
/// Override: `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000`
abstract final class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (Platform.isAndroid) {
      // Emulador Android → host machine
      return 'http://10.0.2.2:8000';
    }

    // iOS Simulator, macOS desktop — localhost do Mac
    return 'http://127.0.0.1:8000';
  }
}

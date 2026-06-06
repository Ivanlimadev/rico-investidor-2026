import 'package:rico_investidor/core/network/api_exception.dart';

bool isMarketstackQuotaError(Object? error) {
  if (error is! ApiException) return false;
  final message = error.message.toLowerCase();
  return error.statusCode == 503 &&
      (message.contains('cota') || message.contains('quota') || message.contains('esgotada'));
}

String marketstackErrorMessage(Object? error, {required String fallback}) {
  if (isMarketstackQuotaError(error)) {
    return 'Limite de consultas atingido. Tente novamente mais tarde.';
  }
  // Nunca repassa mensagens brutas de rede/exceção para a UI.
  return fallback;
}

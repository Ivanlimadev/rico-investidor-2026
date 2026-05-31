import 'package:rico_investidor/core/network/api_exception.dart';

bool isMarketstackQuotaError(Object? error) {
  if (error is! ApiException) return false;
  final message = error.message.toLowerCase();
  return error.statusCode == 503 &&
      (message.contains('cota') || message.contains('quota') || message.contains('esgotada'));
}

String marketstackErrorMessage(Object? error, {required String fallback}) {
  if (isMarketstackQuotaError(error)) {
    return 'Cota mensal da Marketstack esgotada. '
        'Aguarde a renovação do plano ou reduza o uso por enquanto.';
  }
  return fallback;
}

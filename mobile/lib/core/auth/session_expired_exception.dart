/// Sessão registrada expirou — o app deve pedir login novamente.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

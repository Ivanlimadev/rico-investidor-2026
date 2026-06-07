import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/auth/screens/auth_welcome_screen.dart';

/// Exige conta registrada antes de alterar a carteira.
Future<bool> ensureRegisteredForPortfolio(
  BuildContext context, {
  required Future<void> Function() onAccountReady,
}) async {
  if (authSession.isRegisteredSession) return true;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AuthWelcomeScreen(
        onCompleted: onAccountReady,
        onSkip: () => Navigator.of(context).pop(),
      ),
    ),
  );

  return authSession.isRegisteredSession;
}

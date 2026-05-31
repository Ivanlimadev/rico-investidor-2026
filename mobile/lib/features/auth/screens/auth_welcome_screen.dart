import 'package:flutter/material.dart';
import 'package:rico_investidor/features/auth/screens/login_screen.dart';
import 'package:rico_investidor/features/auth/screens/register_screen.dart';

/// Primeira etapa do app: criar conta, entrar ou continuar sem cadastro.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({
    super.key,
    required this.onCompleted,
    required this.onSkip,
  });

  final VoidCallback onCompleted;
  final VoidCallback onSkip;

  void _openRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(
          onSuccess: () {
            Navigator.of(context).pop();
            onCompleted();
          },
        ),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          onSuccess: () {
            Navigator.of(context).pop();
            onCompleted();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Bem-vindo ao Rico Investidor',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Crie sua conta para salvar carteira, preferências e acessar de qualquer dispositivo.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => _openRegister(context),
                child: const Text('Criar conta'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openLogin(context),
                child: const Text('Já tenho conta'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSkip,
                child: const Text('Continuar sem cadastro'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

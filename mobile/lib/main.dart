import 'package:flutter/material.dart';
import 'package:rico_investidor/app/rico_investidor_app.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Valida URL cedo (release exige HTTPS via dart-define).
    ApiConfig.baseUrl;
  } on ApiConfigError catch (error) {
    runApp(_ConfigErrorApp(message: error.message));
    return;
  }

  try {
    await authSession.ensureAuthenticated();
  } catch (_) {
    // Auth falhou — app ainda abre; telas mostram erro de rede.
  }

  runApp(const RicoInvestidorApp());
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuração da API',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

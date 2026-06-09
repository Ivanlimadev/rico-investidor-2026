import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/finances/data/plaid_link_service.dart';

class PlaidLinkScreen extends StatefulWidget {
  const PlaidLinkScreen({
    super.key,
    required this.onRequireAuth,
  });

  final VoidCallback onRequireAuth;

  @override
  State<PlaidLinkScreen> createState() => _PlaidLinkScreenState();
}

class _PlaidLinkScreenState extends State<PlaidLinkScreen> {
  String? _error;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!authSession.isRegisteredSession) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crie uma conta para conectar seu banco')),
      );
      Navigator.of(context).pop();
      widget.onRequireAuth();
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final result = await plaidLinkService.connect();
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on StateError catch (error) {
      if (!mounted) return;
      if (error.message == 'Conexão cancelada') {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _error = error.message;
        _connecting = false;
      });
    } on UnsupportedError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message ?? 'Plaid não suportado nesta plataforma';
        _connecting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível conectar ao banco. Verifique sua conexão e as chaves Plaid.';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar banco'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_connecting) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _connecting
                          ? 'Abrindo Plaid Link…'
                          : 'Preparando conexão segura',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _start,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

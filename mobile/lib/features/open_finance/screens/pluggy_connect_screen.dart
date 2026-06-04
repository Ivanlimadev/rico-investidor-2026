import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pluggy_connect/flutter_pluggy_connect.dart';
import 'package:rico_investidor/features/open_finance/data/open_finance_repository.dart';

class PluggyConnectResult {
  const PluggyConnectResult({required this.itemId});

  final String itemId;
}

class PluggyConnectScreen extends StatefulWidget {
  const PluggyConnectScreen({
    super.key,
    required this.connectToken,
    required this.repository,
  });

  final String connectToken;
  final OpenFinanceRepository repository;

  @override
  State<PluggyConnectScreen> createState() => _PluggyConnectScreenState();
}

class _PluggyConnectScreenState extends State<PluggyConnectScreen> {
  var _registering = false;
  var _finished = false;

  Future<void> _handleSuccess(dynamic data) async {
    if (_finished || _registering) return;

    final itemId = _extractItemId(data);
    if (itemId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexão concluída, mas não foi possível identificar a instituição.')),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _registering = true);
    try {
      await widget.repository.registerItem(itemId: itemId);
      if (!mounted) return;
      _finished = true;
      Navigator.of(context).pop(PluggyConnectResult(itemId: itemId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _registering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar conexão. Tente novamente.')),
      );
    }
  }

  String? _extractItemId(dynamic data) {
    if (data is Map) {
      final item = data['item'];
      if (item is Map && item['id'] != null) {
        return item['id'].toString();
      }
      if (data['id'] != null) {
        return data['id'].toString();
      }
    }

    try {
      final decoded = jsonDecode(jsonEncode(data));
      if (decoded is Map<String, dynamic>) {
        return _extractItemId(decoded);
      }
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar investimentos'),
        actions: [
          if (_registering)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          PluggyConnect(
            connectToken: widget.connectToken,
            includeSandbox: kDebugMode,
            onSuccess: _handleSuccess,
            onClose: () {
              if (!_finished && mounted) Navigator.of(context).pop();
            },
            onError: (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    kDebugMode ? 'Falha na conexão: $error' : 'Falha na conexão. Tente novamente.',
                  ),
                ),
              );
            },
          ),
          if (_registering)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

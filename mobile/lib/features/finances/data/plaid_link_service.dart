import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';

class PlaidLinkConnectResult {
  const PlaidLinkConnectResult({
    required this.exchange,
    this.accountLabels = const [],
  });

  final ExchangeTokenResult exchange;
  final List<String> accountLabels;
}

class PlaidLinkService {
  PlaidLinkService({FinancesRepository? repository})
      : _repository = repository ?? financesRepository;

  final FinancesRepository _repository;

  bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<PlaidLinkConnectResult> connect() async {
    if (!authSession.isRegisteredSession) {
      throw StateError('Conta registrada necessária para conectar banco');
    }
    if (!isSupported) {
      throw UnsupportedError(
        'Plaid Link está disponível no iPhone, Android ou Chrome. No app desktop use Chrome ou o simulador iOS.',
      );
    }

    final linkToken = await _repository.createLinkToken();
    if (linkToken.isEmpty) {
      throw StateError('Link token inválido');
    }

    final completer = Completer<PlaidLinkConnectResult>();
    late final StreamSubscription<LinkSuccess> successSub;
    late final StreamSubscription<LinkExit> exitSub;

    successSub = PlaidLink.onSuccess.listen((event) async {
      await successSub.cancel();
      await exitSub.cancel();
      try {
        final exchange = await _repository.exchangePublicToken(event.publicToken);
        final accounts = await _repository.loadDashboard(forceRefresh: true);
        final labels = accounts.accounts
            .map((a) => '${a.name} ····${a.mask}')
            .take(4)
            .toList();
        if (!completer.isCompleted) {
          completer.complete(
            PlaidLinkConnectResult(exchange: exchange, accountLabels: labels),
          );
        }
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      }
    });

    exitSub = PlaidLink.onExit.listen((event) async {
      await successSub.cancel();
      await exitSub.cancel();
      if (!completer.isCompleted) {
        if (event.error != null) {
          completer.completeError(
            StateError(event.error?.displayMessage ?? event.error?.message ?? 'Plaid encerrado'),
          );
        } else {
          completer.completeError(StateError('Conexão cancelada'));
        }
      }
    });

    try {
      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: linkToken),
      );
      await PlaidLink.open();
    } catch (error, stack) {
      await successSub.cancel();
      await exitSub.cancel();
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    }

    return completer.future;
  }
}

final plaidLinkService = PlaidLinkService();

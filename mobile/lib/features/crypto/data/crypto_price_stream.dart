import 'dart:async';
import 'dart:convert';

import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CryptoLiveTrade {
  const CryptoLiveTrade({required this.price, this.time});

  final double price;
  final String? time;
}

/// Preço em tempo real via WebSocket público da Binance (`@trade`).
class CryptoPriceStream {
  CryptoPriceStream({
    required this.symbol,
    required this.onTrade,
    this.onError,
    this.onDone,
  });

  final String symbol;
  final void Function(CryptoLiveTrade trade) onTrade;
  final void Function(Object error)? onError;
  final void Function()? onDone;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  static String streamUrlFor(String symbol) {
    final pair = '${normalizeCryptoSymbol(symbol).toLowerCase()}usdt';
    return 'wss://stream.binance.com:9443/ws/$pair@trade';
  }

  void connect() {
    close();
    _channel = WebSocketChannel.connect(Uri.parse(streamUrlFor(symbol)));
    _subscription = _channel!.stream.listen(
      (event) {
        if (event is! String) return;
        final data = jsonDecode(event) as Map<String, dynamic>;
        if (data['e'] != 'trade') return;
        final rawPrice = data['p'];
        if (rawPrice == null) return;
        final price = double.tryParse(rawPrice.toString());
        if (price == null) return;
        final tradeTime = data['T'];
        onTrade(
          CryptoLiveTrade(
            price: price,
            time: tradeTime?.toString(),
          ),
        );
      },
      onError: onError,
      onDone: onDone,
    );
  }

  void close() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}

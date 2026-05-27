import 'dart:async';
import 'dart:convert';

import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CryptoLiveQuote {
  const CryptoLiveQuote({
    required this.symbol,
    required this.price,
    this.changePercent,
  });

  final String symbol;
  final double price;
  final double? changePercent;
}

/// Atualizações leves via combined stream `@miniTicker` (Binance pública).
class CryptoMiniTickerStream {
  CryptoMiniTickerStream({required this.onQuote});

  final void Function(CryptoLiveQuote quote) onQuote;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  static String streamUrlFor(Iterable<String> symbols) {
    final streams = symbols
        .map((symbol) => '${normalizeCryptoSymbol(symbol).toLowerCase()}usdt@miniTicker')
        .join('/');
    return 'wss://stream.binance.com:9443/stream?streams=$streams';
  }

  void connect(Iterable<String> symbols) {
    close();
    final unique = symbols.map(normalizeCryptoSymbol).where((symbol) => symbol.isNotEmpty).toSet();
    if (unique.isEmpty) return;

    _channel = WebSocketChannel.connect(Uri.parse(streamUrlFor(unique)));
    _subscription = _channel!.stream.listen((event) {
      if (event is! String) return;
      final envelope = jsonDecode(event) as Map<String, dynamic>;
      final data = envelope['data'];
      if (data is! Map<String, dynamic>) return;

      final price = double.tryParse('${data['c']}');
      if (price == null) return;

      final open = double.tryParse('${data['o']}');
      double? changePercent;
      if (open != null && open > 0) {
        changePercent = ((price - open) / open) * 100;
      }

      final symbol = normalizeCryptoSymbol('${data['s']}');
      onQuote(CryptoLiveQuote(symbol: symbol, price: price, changePercent: changePercent));
    });
  }

  void close() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}

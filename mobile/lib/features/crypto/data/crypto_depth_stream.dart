import 'dart:async';
import 'dart:convert';

import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Livro parcial (top 10) via WebSocket `@depth10@100ms`.
class CryptoDepthStream {
  CryptoDepthStream({
    required this.symbol,
    required this.onBook,
    this.onError,
    this.onDone,
  });

  final String symbol;
  final void Function(CryptoOrderBookDto book) onBook;
  final void Function(Object error)? onError;
  final void Function()? onDone;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  static String streamUrlFor(String symbol) {
    final pair = '${normalizeCryptoSymbol(symbol).toLowerCase()}usdt';
    return 'wss://stream.binance.com:9443/ws/$pair@depth10@100ms';
  }

  void connect() {
    close();
    _channel = WebSocketChannel.connect(Uri.parse(streamUrlFor(symbol)));
    _subscription = _channel!.stream.listen(
      (event) {
        if (event is! String) return;
        final payload = jsonDecode(event) as Map<String, dynamic>;
        final book = _parseBook(payload);
        if (book != null) onBook(book);
      },
      onError: onError,
      onDone: onDone,
    );
  }

  CryptoOrderBookDto? _parseBook(Map<String, dynamic> payload) {
    final bidsRaw = payload['bids'] as List<dynamic>? ?? payload['b'] as List<dynamic>?;
    final asksRaw = payload['asks'] as List<dynamic>? ?? payload['a'] as List<dynamic>?;
    if (bidsRaw == null || asksRaw == null) return null;

    List<CryptoOrderBookLevelDto> levels(List<dynamic> raw) {
      final levels = <CryptoOrderBookLevelDto>[];
      for (final item in raw) {
        if (item is! List || item.length < 2) continue;
        final price = double.tryParse('${item[0]}');
        final qty = double.tryParse('${item[1]}');
        if (price == null || qty == null || qty <= 0) continue;
        levels.add(CryptoOrderBookLevelDto(price: price, quantity: qty));
      }
      return levels;
    }

    final normalized = normalizeCryptoSymbol(symbol);
    return CryptoOrderBookDto(
      symbol: normalized,
      bids: levels(bidsRaw),
      asks: levels(asksRaw),
    );
  }

  void close() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}

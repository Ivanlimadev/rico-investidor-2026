/// Timeout padrão para preloads e dados secundários (hub, demonstrações).
const kRepositoryFetchTimeout = Duration(seconds: 10);

/// Timeout para cotações/mercado — falha rápido se o backend estiver offline.
const kMarketApiTimeout = Duration(seconds: 15);

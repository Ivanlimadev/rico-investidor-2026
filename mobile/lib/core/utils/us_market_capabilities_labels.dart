import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

/// Sessão US com intraday ativo (pregão, pré ou after).
bool usMarketSessionUsesIntraday(GlobalMarketCapabilitiesDto caps) {
  if (!caps.realtimeEnabled) return false;
  if (caps.usMarketOpen) return true;
  final status = caps.usMarketStatus.toLowerCase();
  return status == 'premarket' || status == 'afterhours';
}

/// Exibe aviso de atraso do feed intraday Marketstack (~15 min).
bool shouldShowUsIntradayDelayNotice(GlobalMarketCapabilitiesDto caps) {
  final delay = caps.intradayDelayMinutes;
  return delay != null && delay > 0 && usMarketSessionUsesIntraday(caps);
}

String usIntradayDelayChipLabel(GlobalMarketCapabilitiesDto caps) {
  final minutes = caps.intradayDelayMinutes ?? 15;
  return '~$minutes min de atraso';
}

String usRealtimeQuoteCaption(GlobalMarketCapabilitiesDto? caps, {required bool quoteLive}) {
  if (caps != null && shouldShowUsIntradayDelayNotice(caps)) {
    return 'Cotação com ${usIntradayDelayChipLabel(caps).replaceFirst('~', 'aprox. ')}';
  }
  if (quoteLive) return 'Cotação ao vivo';
  return 'Tempo real';
}

String usRealtimeQuoteChipLabel(GlobalMarketCapabilitiesDto? caps, {required bool quoteLive}) {
  if (caps != null && shouldShowUsIntradayDelayNotice(caps)) {
    return usIntradayDelayChipLabel(caps);
  }
  return quoteLive ? 'Ao vivo' : 'Tempo real';
}

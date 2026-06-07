import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/us_market_capabilities_labels.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

GlobalMarketCapabilitiesDto _caps({
  bool realtime = true,
  bool open = true,
  String status = 'open',
  int? delay = 15,
}) {
  return GlobalMarketCapabilitiesDto(
    plan: 'professional',
    dataMode: 'realtime',
    maxHistoryDays: 1260,
    realtimeEnabled: realtime,
    fundamentalsEnabled: false,
    usMarketOpen: open,
    usMarketStatus: status,
    intradayDelayMinutes: delay,
  );
}

void main() {
  test('shows delay notice during regular session with realtime', () {
    expect(shouldShowUsIntradayDelayNotice(_caps()), isTrue);
    expect(usIntradayDelayChipLabel(_caps()), '~15 min de atraso');
  });

  test('hides delay notice when market is closed', () {
    expect(
      shouldShowUsIntradayDelayNotice(_caps(open: false, status: 'closed')),
      isFalse,
    );
  });

  test('shows delay notice during premarket', () {
    expect(
      shouldShowUsIntradayDelayNotice(_caps(open: false, status: 'premarket')),
      isTrue,
    );
  });

  test('realtime caption mentions delay instead of ao vivo', () {
    final caption = usRealtimeQuoteCaption(_caps(), quoteLive: true);
    expect(caption, contains('aprox.'));
    expect(caption, isNot(contains('ao vivo')));
  });
}

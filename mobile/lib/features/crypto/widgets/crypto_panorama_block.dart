import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/utils/crypto_display_locale.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_fundamentals_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_performance_row.dart';

/// Panorama da cripto referência (macro + variações + fundamentos).
class CryptoPanoramaBlock extends StatefulWidget {
  const CryptoPanoramaBlock({
    super.key,
    this.symbol = 'BTC',
    this.repository,
  });

  final String symbol;
  final CryptoRepository? repository;

  @override
  State<CryptoPanoramaBlock> createState() => _CryptoPanoramaBlockState();
}

class _CryptoPanoramaBlockState extends State<CryptoPanoramaBlock> {
  late Future<({CryptoMacroSnapshotDto? macro, CryptoInvestorProfileDto? profile})> _future;

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({CryptoMacroSnapshotDto? macro, CryptoInvestorProfileDto? profile})> _load() async {
    try {
      await authSession.ensureAuthenticated();
      final results = await Future.wait([
        _repository.getMacro(),
        _repository.getProfile(widget.symbol),
      ]);
      return (
        macro: results[0] as CryptoMacroSnapshotDto,
        profile: results[1] as CryptoInvestorProfileDto,
      );
    } catch (_) {
      return (macro: null, profile: null);
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final showBrazilianQuotes = cryptoShowsBrazilianQuotes(context);

    return FutureBuilder<({CryptoMacroSnapshotDto? macro, CryptoInvestorProfileDto? profile})>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        final data = snapshot.data;
        if (data == null || (data.macro == null && data.profile == null)) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Recarregar panorama'),
            ),
          );
        }

        final profile = data.profile;
        final macro = data.macro;
        final cryptoName = profile?.quote.name ?? widget.symbol;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _PanoramaCard(
            cryptoName: cryptoName,
            macro: macro,
            profile: profile,
            showBrazilianQuotes: showBrazilianQuotes,
          ),
        );
      },
    );
  }
}

class _PanoramaCard extends StatelessWidget {
  const _PanoramaCard({
    required this.cryptoName,
    required this.macro,
    required this.profile,
    required this.showBrazilianQuotes,
  });

  final String cryptoName;
  final CryptoMacroSnapshotDto? macro;
  final CryptoInvestorProfileDto? profile;
  final bool showBrazilianQuotes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2230), const Color(0xFF121820)]
              : [const Color(0xFFF7F9FC), const Color(0xFFEEF2F7)],
        ),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7A23B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.currency_bitcoin_rounded, color: Color(0xFFF7A23B), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Panorama · $cryptoName',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (macro != null) ...[
              const SizedBox(height: 16),
              _VisualMetricsRow(
                macro: macro!,
                showBrazilianQuotes: showBrazilianQuotes,
                isDark: isDark,
              ),
            ],
            if (profile != null) ...[
              const SizedBox(height: 14),
              CryptoPerformanceRow(performance: profile!.performance),
              const SizedBox(height: 10),
              CryptoFundamentalsCard(
                fundamentals: profile!.fundamentals,
                brl: profile!.brl,
                showBrazilianQuotes: showBrazilianQuotes,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisualMetricsRow extends StatelessWidget {
  const _VisualMetricsRow({
    required this.macro,
    required this.showBrazilianQuotes,
    required this.isDark,
  });

  final CryptoMacroSnapshotDto macro;
  final bool showBrazilianQuotes;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 400;
        if (stacked) {
          return Column(
            children: [
              if (macro.btcDominance != null) _DominancePanel(dominance: macro.btcDominance!, isDark: isDark),
              if (macro.fearGreedIndex != null) ...[
                const SizedBox(height: 10),
                _FearGreedPanel(index: macro.fearGreedIndex!, label: macro.fearGreedLabel, isDark: isDark),
              ],
              if (_hasSecondaryMetrics) ...[
                const SizedBox(height: 10),
                _SecondaryMetricsRow(macro: macro, showBrazilianQuotes: showBrazilianQuotes, isDark: isDark),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (macro.btcDominance != null)
                  Expanded(
                    child: _DominancePanel(dominance: macro.btcDominance!, isDark: isDark),
                  ),
                if (macro.btcDominance != null && macro.fearGreedIndex != null) const SizedBox(width: 10),
                if (macro.fearGreedIndex != null)
                  Expanded(
                    child: _FearGreedPanel(index: macro.fearGreedIndex!, label: macro.fearGreedLabel, isDark: isDark),
                  ),
              ],
            ),
            if (_hasSecondaryMetrics) ...[
              const SizedBox(height: 10),
              _SecondaryMetricsRow(macro: macro, showBrazilianQuotes: showBrazilianQuotes, isDark: isDark),
            ],
          ],
        );
      },
    );
  }

  bool get _hasSecondaryMetrics =>
      macro.totalVolume24hUsd != null || (showBrazilianQuotes && macro.usdtBrlRate != null);
}

class _DominancePanel extends StatelessWidget {
  const _DominancePanel({required this.dominance, required this.isDark});

  final double dominance;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final clamped = dominance.clamp(0, 100).toDouble();
    final rest = (100 - clamped).clamp(0, 100).toDouble();

    return _MetricPanel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dominância BTC',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _DominanceDonutPainter(
                    dominance: clamped / 100,
                    accent: const Color(0xFFF7A23B),
                    track: isDark ? const Color(0xFF2B3139) : const Color(0xFFE2E8F0),
                  ),
                  child: Center(
                    child: Text(
                      '${clamped.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StackBarSegment(
                      label: 'BTC',
                      percent: clamped,
                      color: const Color(0xFFF7A23B),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    _StackBarSegment(
                      label: 'Outras',
                      percent: rest,
                      color: isDark ? const Color(0xFF5B8DEF) : const Color(0xFF94A3B8),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackBarSegment extends StatelessWidget {
  const _StackBarSegment({
    required this.label,
    required this.percent,
    required this.color,
    required this.isDark,
  });

  final String label;
  final double percent;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.01, 1.0),
            minHeight: 6,
            backgroundColor: isDark ? const Color(0xFF2B3139) : const Color(0xFFE2E8F0),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FearGreedPanel extends StatelessWidget {
  const _FearGreedPanel({
    required this.index,
    required this.label,
    required this.isDark,
  });

  final int index;
  final String? label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, 100);
    final labelPt = _fearGreedLabelPt(label);
    final color = _fearGreedColor(safeIndex);

    return _MetricPanel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sentimento do mercado',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 12),
          _FearGreedLevelBar(index: safeIndex, isDark: isDark),
          const SizedBox(height: 8),
          Text(
            labelPt.isNotEmpty ? labelPt : 'Indefinido',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Medo', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
              Text('Neutro', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
              Text('Ganância', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FearGreedLevelBar extends StatelessWidget {
  const _FearGreedLevelBar({required this.index, required this.isDark});

  final int index;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const barHeight = 12.0;
        const thumbSize = 16.0;
        final thumbLeft = (index / 100 * width - thumbSize / 2).clamp(0.0, width - thumbSize);

        return SizedBox(
          height: thumbSize + 4,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(barHeight),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.negative,
                      Color(0xFFE67E22),
                      Color(0xFF95A5A6),
                      Color(0xFF27AE60),
                      AppColors.positive,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white : Colors.white,
                    border: Border.all(color: _fearGreedColor(index), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SecondaryMetricsRow extends StatelessWidget {
  const _SecondaryMetricsRow({
    required this.macro,
    required this.showBrazilianQuotes,
    required this.isDark,
  });

  final CryptoMacroSnapshotDto macro;
  final bool showBrazilianQuotes;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (macro.totalVolume24hUsd != null)
          Expanded(
            child: _CompactStat(
              icon: Icons.swap_vert_rounded,
              label: 'Volume 24h',
              value: formatCryptoVolume(macro.totalVolume24hUsd!),
              accent: const Color(0xFF5B8DEF),
              isDark: isDark,
            ),
          ),
        if (macro.totalVolume24hUsd != null && showBrazilianQuotes && macro.usdtBrlRate != null)
          const SizedBox(width: 10),
        if (showBrazilianQuotes && macro.usdtBrlRate != null)
          Expanded(
            child: _CompactStat(
              icon: Icons.attach_money_rounded,
              label: 'USDT/BRL',
              value: 'R\$${macro.usdtBrlRate!.toStringAsFixed(4)}',
              accent: const Color(0xFF0ABF7A),
              isDark: isDark,
            ),
          ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _MetricPanel(
      isDark: isDark,
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: child,
    );
  }
}

class _DominanceDonutPainter extends CustomPainter {
  _DominanceDonutPainter({
    required this.dominance,
    required this.accent,
    required this.track,
  });

  final double dominance;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const stroke = 9.0;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * dominance;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(_DominanceDonutPainter oldDelegate) =>
      oldDelegate.dominance != dominance || oldDelegate.accent != accent;
}

Color _fearGreedColor(int index) {
  if (index <= 25) return AppColors.negative;
  if (index <= 45) return const Color(0xFFE67E22);
  if (index <= 55) return const Color(0xFF95A5A6);
  if (index <= 75) return const Color(0xFF27AE60);
  return AppColors.positive;
}

String _fearGreedLabelPt(String? label) {
  if (label == null || label.isEmpty) return '';
  return switch (label.toLowerCase()) {
    'extreme fear' => 'Medo extremo',
    'fear' => 'Medo',
    'neutral' => 'Neutro',
    'greed' => 'Ganância',
    'extreme greed' => 'Ganância extrema',
    _ => label,
  };
}
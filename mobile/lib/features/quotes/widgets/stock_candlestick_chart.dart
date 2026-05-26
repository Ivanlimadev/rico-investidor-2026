import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/models/fii_models.dart';

class StockCandlestickChart extends StatelessWidget {
  const StockCandlestickChart({
    super.key,
    required this.bars,
    required this.period,
    this.selectedIndex,
    this.onSelected,
    this.leftPadding = 48,
    this.bottomPadding = 26,
  });

  final List<FiiCandleBar> bars;
  final FiiQuotePeriod period;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final double leftPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (bars.length < 2) {
      return const SizedBox.shrink();
    }

    final minY = bars.map((bar) => bar.low).reduce(math.min);
    final maxY = bars.map((bar) => bar.high).reduce(math.max);
    final padding = ((maxY - minY).abs() * 0.08).clamp(0.2, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;
    final yInterval = niceYInterval(yMin, yMax);
    final scrollWidth = quoteChartScrollWidth(bars.length);

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final index = _indexForX(
              details.localPosition.dx,
              chartWidth: constraints.maxWidth,
              count: bars.length,
            );
            if (index != null) onSelected?.call(index);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _CandlestickPainter(
              bars: bars,
              period: period,
              selectedIndex: selectedIndex,
              yMin: yMin,
              yMax: yMax,
              yInterval: yInterval,
              leftPadding: leftPadding,
              bottomPadding: bottomPadding,
              dividerColor: Theme.of(context).dividerColor,
              labelStyle: Theme.of(context).textTheme.labelSmall,
              bullishColor: AppColors.positive,
              bearishColor: AppColors.negative,
            ),
          ),
        );
      },
    );

    if (scrollWidth > 0) {
      chart = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: scrollWidth, height: double.infinity, child: chart),
      );
    }

    return chart;
  }

  int? _indexForX(double x, {required double chartWidth, required int count}) {
    if (count <= 0) return null;
    final plotWidth = math.max(chartWidth - leftPadding, 1);
    final slot = plotWidth / count;
    final adjusted = x - leftPadding;
    if (adjusted < 0 || adjusted > plotWidth) return null;
    return (adjusted / slot).floor().clamp(0, count - 1);
  }
}

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter({
    required this.bars,
    required this.period,
    required this.selectedIndex,
    required this.yMin,
    required this.yMax,
    required this.yInterval,
    required this.leftPadding,
    required this.bottomPadding,
    required this.dividerColor,
    required this.labelStyle,
    required this.bullishColor,
    required this.bearishColor,
  });

  final List<FiiCandleBar> bars;
  final FiiQuotePeriod period;
  final int? selectedIndex;
  final double yMin;
  final double yMax;
  final double yInterval;
  final double leftPadding;
  final double bottomPadding;
  final Color dividerColor;
  final TextStyle? labelStyle;
  final Color bullishColor;
  final Color bearishColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = 8.0;
    final plotBottom = size.height - bottomPadding;
    final plotHeight = math.max(plotBottom - plotTop, 1.0);
    final plotLeft = leftPadding;
    final plotRight = size.width;
    final plotWidth = math.max(plotRight - plotLeft, 1.0);

    final gridPaint = Paint()
      ..color = dividerColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = dividerColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom), axisPaint);
    canvas.drawLine(Offset(plotLeft, plotTop), Offset(plotLeft, plotBottom), axisPaint);

    for (var value = yMin; value <= yMax + 0.0001; value += yInterval) {
      final y = _yForPrice(value.toDouble(), plotTop: plotTop, plotHeight: plotHeight);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _drawText(
        canvas,
        _formatAxisPrice(value),
        Offset(4, y - 8),
        labelStyle,
        align: TextAlign.left,
      );
    }

    final slotWidth = plotWidth / bars.length;
    final bodyWidth = (slotWidth * 0.55).clamp(2.0, 10.0);

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final centerX = plotLeft + (i + 0.5) * slotWidth;
      final bullish = bar.close >= bar.open;
      final color = bullish ? bullishColor : bearishColor;
      final isSelected = selectedIndex == i;

      final openY = _yForPrice(bar.open.toDouble(), plotTop: plotTop, plotHeight: plotHeight);
      final closeY = _yForPrice(bar.close.toDouble(), plotTop: plotTop, plotHeight: plotHeight);
      final highY = _yForPrice(bar.high.toDouble(), plotTop: plotTop, plotHeight: plotHeight);
      final lowY = _yForPrice(bar.low.toDouble(), plotTop: plotTop, plotHeight: plotHeight);

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = isSelected ? 2 : 1.2;
      canvas.drawLine(Offset(centerX, highY), Offset(centerX, lowY), wickPaint);

      final top = math.min(openY, closeY);
      final bottom = math.max(openY, closeY);
      final bodyHeight = math.max(bottom - top, 1.2);
      final bodyRect = Rect.fromCenter(
        center: Offset(centerX, (top + bottom) / 2),
        width: bodyWidth,
        height: bodyHeight,
      );

      final bodyPaint = Paint()..color = color.withValues(alpha: isSelected ? 1 : 0.88);
      canvas.drawRect(bodyRect, bodyPaint);

      if (isSelected) {
        final border = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(bodyRect.inflate(1), border);
      }
    }

    for (var i = 0; i < bars.length; i++) {
      final label = axisLabelForIndex(bars, i, period);
      if (label.isEmpty) continue;
      final centerX = plotLeft + (i + 0.5) * slotWidth;
      _drawText(
        canvas,
        label,
        Offset(centerX - 16, plotBottom + 6),
        labelStyle,
        align: TextAlign.center,
      );
    }
  }

  double _yForPrice(double price, {required double plotTop, required double plotHeight}) {
    final ratio = (price - yMin) / (yMax - yMin);
    return plotTop + plotHeight * (1 - ratio);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle? style, {
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 44);
    final dx = switch (align) {
      TextAlign.center => offset.dx - painter.width / 2,
      TextAlign.right => offset.dx - painter.width,
      _ => offset.dx,
    };
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  String _formatAxisPrice(double value) {
    if (value >= 1000) return value.toStringAsFixed(0);
    if (value >= 100) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax;
  }
}

class StockSelectedCandleBar extends StatelessWidget {
  const StockSelectedCandleBar({super.key, required this.bar});

  final FiiCandleBar bar;

  @override
  Widget build(BuildContext context) {
    final bullish = bar.close >= bar.open;
    final changeColor = bullish ? AppColors.positive : AppColors.negative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(formatQuoteDate(bar.tradeDate), style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              formatBrl(bar.close),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: changeColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _OhlcChip(label: 'A', value: bar.open),
            _OhlcChip(label: 'M', value: bar.high),
            _OhlcChip(label: 'm', value: bar.low),
            _OhlcChip(label: 'F', value: bar.close, highlight: true),
          ],
        ),
      ],
    );
  }
}

class _OhlcChip extends StatelessWidget {
  const _OhlcChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label ${formatBrl(value)}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            color: highlight
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
    );
  }
}

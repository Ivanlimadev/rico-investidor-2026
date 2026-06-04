import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Mini-gráfico estilo Twelve Data (lista de ativos).
class QuoteSparkline extends StatelessWidget {
  const QuoteSparkline({
    super.key,
    required this.values,
    required this.positive,
    this.width = 76,
    this.height = 34,
  });

  final List<double> values;
  final bool positive;
  final double width;
  final double height;

  static const Color _upColor = Color(0xFF3B82F6);
  static const Color _downColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(width: width, height: height);
    }

    final lineColor = positive ? _upColor : _downColor;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          lineColor: lineColor,
          fillColor: lineColor.withValues(alpha: positive ? 0.14 : 0.08),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _normalizedPoints(size);
    if (points.length < 2) return;

    final smooth = _smoothPath(points);
    final fill = Path.from(smooth)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.35),
          Offset(0, size.height),
          [fillColor, fillColor.withValues(alpha: 0.01)],
        ),
    );

    canvas.drawPath(
      smooth,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  List<Offset> _normalizedPoints(Size size) {
    var minY = values.first;
    var maxY = values.first;
    for (final value in values) {
      if (value < minY) minY = value;
      if (value > maxY) maxY = value;
    }
    final range = (maxY - minY).abs();
    final pad = range < 1e-6 ? 1.0 : range * 0.06;
    final lo = minY - pad;
    final hi = maxY + pad;
    final span = (hi - lo).abs().clamp(1e-6, double.infinity);

    final insetV = 3.0;
    final plotH = size.height - insetV * 2;
    final plotW = size.width;

    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1 ? 0 : (i / (values.length - 1)) * plotW,
          size.height - insetV - ((values[i] - lo) / span) * plotH,
        ),
    ];
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

/// Badge de variação estilo Twelve Data.
class QuoteChangeBadge extends StatelessWidget {
  const QuoteChangeBadge({
    super.key,
    required this.changePercent,
    required this.positive,
  });

  final double changePercent;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = positive
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final fg = positive
        ? Colors.white
        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

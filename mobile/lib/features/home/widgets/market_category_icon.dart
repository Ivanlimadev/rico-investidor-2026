import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rico_investidor/models/market_category_icon_kind.dart';

/// Ícones vetoriais — bandeira BR com losango amarelo (proporção correta).
class MarketCategoryIcon extends StatelessWidget {
  const MarketCategoryIcon({
    super.key,
    required this.kind,
    this.size = 48,
    this.iconColor,
    this.accentColor,
  });

  final MarketCategoryIconKind kind;
  final double size;
  final Color? iconColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: switch (kind) {
        MarketCategoryIconKind.brazilFlag => _FlagFrame(
            size: size,
            accent: accentColor ?? const Color(0xFFFF6B35),
            child: _BrazilFlag(size: size * 0.88),
          ),
        MarketCategoryIconKind.usFlag => _FlagFrame(
            size: size,
            accent: accentColor ?? const Color(0xFFFF5C5C),
            child: _UsFlag(size: size * 0.88),
          ),
        MarketCategoryIconKind.bitcoin => _BitcoinMark(
          size: size,
          accent: accentColor ?? const Color(0xFFFF8C42),
        ),
        MarketCategoryIconKind.fiiBuilding => _WarmGlyphIcon(
          icon: Icons.apartment_rounded,
          color: iconColor ?? const Color(0xFFFFD180),
          accent: accentColor ?? const Color(0xFFFFB347),
          size: size,
          badge: _BrazilFlag(size: size * 0.34),
        ),
        MarketCategoryIconKind.globe => _WarmGlyphIcon(
          icon: Icons.public_rounded,
          color: iconColor ?? const Color(0xFFFF8A9B),
          accent: accentColor ?? const Color(0xFFE85D75),
          size: size,
        ),
        MarketCategoryIconKind.chartBr => _WarmGlyphIcon(
          icon: Icons.bar_chart_rounded,
          color: iconColor ?? const Color(0xFFFFD166),
          accent: accentColor ?? const Color(0xFFE8A838),
          size: size,
          badge: _BrazilFlag(size: size * 0.34),
        ),
        MarketCategoryIconKind.chartGlobal => _WarmGlyphIcon(
          icon: Icons.candlestick_chart_rounded,
          color: iconColor ?? const Color(0xFFFF9EB6),
          accent: accentColor ?? const Color(0xFFFF6F91),
          size: size,
          badge: _UsFlag(size: size * 0.34),
        ),
        MarketCategoryIconKind.reits => _WarmGlyphIcon(
          icon: Icons.home_work_rounded,
          color: iconColor ?? const Color(0xFFFFB3D0),
          accent: accentColor ?? const Color(0xFFFF7EB3),
          size: size,
          badge: _UsFlag(size: size * 0.34),
        ),
        MarketCategoryIconKind.forex => _WarmGlyphIcon(
          icon: Icons.currency_exchange_rounded,
          color: iconColor ?? const Color(0xFFFFC9A8),
          accent: accentColor ?? const Color(0xFFFF9F68),
          size: size,
        ),
        MarketCategoryIconKind.indices => _WarmGlyphIcon(
          icon: Icons.insights_rounded,
          color: iconColor ?? const Color(0xFFFFD98E),
          accent: accentColor ?? const Color(0xFFFFB84D),
          size: size,
        ),
        MarketCategoryIconKind.treasury => _WarmGlyphIcon(
          icon: Icons.account_balance_rounded,
          color: iconColor ?? const Color(0xFF9AE4C8),
          accent: accentColor ?? const Color(0xFF5EC4A8),
          size: size,
          badge: _BrazilFlag(size: size * 0.34),
        ),
      },
    );
  }
}

class _FlagFrame extends StatelessWidget {
  const _FlagFrame({
    required this.size,
    required this.accent,
    required this.child,
  });

  final double size;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A221C),
            const Color(0xFF14100E),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.7),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _WarmGlyphIcon extends StatelessWidget {
  const _WarmGlyphIcon({
    required this.icon,
    required this.color,
    required this.accent,
    required this.size,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final Color accent;
  final double size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 0.94,
          height: size * 0.94,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E2520), Color(0xFF161210)],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.6),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 10),
            ],
          ),
          child: Icon(icon, color: color, size: size * 0.48),
        ),
        if (badge != null)
          Positioned(
            right: -3,
            bottom: -3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: badge,
              ),
            ),
          ),
      ],
    );
  }
}

class _BrazilFlag extends StatelessWidget {
  const _BrazilFlag({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: CustomPaint(
        size: Size(size, size * 0.7),
        painter: const _BrazilFlagPainter(),
      ),
    );
  }
}

class _BrazilFlagPainter extends CustomPainter {
  const _BrazilFlagPainter();

  static const _green = Color(0xFF009739);
  static const _yellow = Color(0xFFFFDF00);
  static const _blue = Color(0xFF002776);
  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = _green);

    final diamond = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.94, h * 0.5)
      ..lineTo(w * 0.5, h * 0.94)
      ..lineTo(w * 0.06, h * 0.5)
      ..close();
    canvas.drawPath(diamond, Paint()..color = _yellow);

    final center = Offset(w * 0.5, h * 0.5);
    canvas.drawCircle(center, w * 0.22, Paint()..color = _blue);

    final band = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: center, width: w * 0.38, height: h * 0.26),
      math.pi * 0.55,
      math.pi * 1.35,
      false,
      band,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UsFlag extends StatelessWidget {
  const _UsFlag({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: CustomPaint(
        size: Size(size, size * 0.7),
        painter: const _UsFlagPainter(),
      ),
    );
  }
}

class _UsFlagPainter extends CustomPainter {
  const _UsFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stripes = 9;
    final stripeH = size.height / stripes;

    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, stripeH * i, size.width, stripeH),
        Paint()..color = i.isEven ? const Color(0xFFB31942) : const Color(0xFFFFFFFF),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.42, size.height * 0.54),
      Paint()..color = const Color(0xFF0A3161),
    );

    final star = Paint()..color = Colors.white;
    const cols = 5;
    const rows = 4;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = (c + (r.isOdd ? 0.5 : 0)) * size.width * 0.075 + size.width * 0.03;
        final dy = r * size.height * 0.11 + size.height * 0.05;
        _drawStar(canvas, Offset(dx, dy), size.width * 0.022, star);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.42;
      final angle = (math.pi / points) * i - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BitcoinMark extends StatelessWidget {
  const _BitcoinMark({required this.size, required this.accent});

  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.94,
      height: size * 0.94,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.65)],
        ),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 14),
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '₿',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bandeira dos EUA desenhada em vetor — não depende de emoji nem rede.
class VectorUsFlag extends StatelessWidget {
  const VectorUsFlag({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(width, height),
          painter: const VectorUsFlagPainter(),
        ),
      ),
    );
  }
}

/// Bandeira do Brasil desenhada em vetor.
class VectorBrazilFlag extends StatelessWidget {
  const VectorBrazilFlag({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(width, height),
          painter: const VectorBrazilFlagPainter(),
        ),
      ),
    );
  }
}

class VectorUsFlagPainter extends CustomPainter {
  const VectorUsFlagPainter();

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

class VectorBrazilFlagPainter extends CustomPainter {
  const VectorBrazilFlagPainter();

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

Widget vectorCountryFlagForCode(
  String? countryCode, {
  required double height,
  double borderRadius = 4,
}) {
  final code = countryCode?.trim().toUpperCase();
  final width = height * 1.45;
  return switch (code) {
    'US' => VectorUsFlag(width: width, height: height, borderRadius: borderRadius),
    'BR' => VectorBrazilFlag(width: width, height: height, borderRadius: borderRadius),
    _ => const SizedBox.shrink(),
  };
}

bool hasVectorCountryFlag(String? countryCode) {
  final code = countryCode?.trim().toUpperCase();
  return code == 'US' || code == 'BR';
}

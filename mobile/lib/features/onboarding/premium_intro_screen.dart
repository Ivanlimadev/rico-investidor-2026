import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta intro: blue-black + platina (premium financeiro).
abstract final class _IntroPalette {
  static const background = Color(0xFF04060C);
  static const midnight = Color(0xFF0A1220);
  static const deepBlue = Color(0xFF142238);
  static const steelBlue = Color(0xFF3D5A80);
  static const iceBlue = Color(0xFF6B8CB8);
  static const platinum = Color(0xFFE8ECF2);
  static const platinumMuted = Color(0xFFB8C2D0);
  static const silver = Color(0xFF9AA8BC);
}

/// Abertura cinematográfica (~5s) — animada, paleta blue-black platina.
class PremiumIntroScreen extends StatefulWidget {
  const PremiumIntroScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<PremiumIntroScreen> createState() => _PremiumIntroScreenState();
}

class _PremiumIntroScreenState extends State<PremiumIntroScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 5000);

  late final AnimationController _controller;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    await _controller.animateTo(1.0, duration: const Duration(milliseconds: 400));
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final fadeOut = t > 0.9 ? Curves.easeIn.transform((t - 0.9) / 0.1) : 0.0;
        final masterOpacity = 1.0 - fadeOut;

        return Opacity(
          opacity: masterOpacity,
          child: ColoredBox(
            color: _IntroPalette.background,
            child: Stack(
            fit: StackFit.expand,
            children: [
              _IntroBackdrop(progress: t),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    _LogoMark(progress: t),
                    const SizedBox(height: 36),
                    _BrandTitle(progress: t),
                    const SizedBox(height: 14),
                    _Tagline(progress: t),
                    const Spacer(flex: 4),
                    _ChartPulse(progress: t),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _IntroBackdrop extends StatelessWidget {
  const _IntroBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IntroBackdropPainter(progress: progress),
      size: Size.infinite,
    );
  }
}

class _IntroBackdropPainter extends CustomPainter {
  _IntroBackdropPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.36);
    final glowStrength = Curves.easeOut.transform(math.min(progress / 0.5, 1.0));

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _IntroPalette.midnight,
          _IntroPalette.background,
          Color.lerp(_IntroPalette.deepBlue, _IntroPalette.background, 0.82)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bg);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _IntroPalette.steelBlue.withValues(alpha: 0.2 * glowStrength),
          _IntroPalette.iceBlue.withValues(alpha: 0.1 * glowStrength),
          _IntroPalette.platinumMuted.withValues(alpha: 0.05 * glowStrength),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.62));
    canvas.drawCircle(center, size.width * 0.62, glow);

    final stripePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _IntroPalette.steelBlue.withValues(alpha: 0.1 * glowStrength),
          Colors.transparent,
          _IntroPalette.platinumMuted.withValues(alpha: 0.04 * glowStrength),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, stripePaint);

    final linePaint = Paint()
      ..color = _IntroPalette.platinum.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const gap = 44.0;
    for (var x = 0.0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = 0.0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final enter = Curves.elasticOut.transform(
      math.max(0, math.min((progress - 0.1) / 0.38, 1.0)),
    );
    final ring = Curves.easeOutCubic.transform(
      math.max(0, math.min((progress - 0.14) / 0.42, 1.0)),
    );
    final scale = 0.72 + enter * 0.28;

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _IntroPalette.platinum.withValues(alpha: 0.2 + ring * 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _IntroPalette.iceBlue.withValues(alpha: 0.35 * ring),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _IntroPalette.steelBlue,
                    _IntroPalette.deepBlue,
                  ],
                ),
              ),
              child: Icon(
                Icons.show_chart_rounded,
                size: 46,
                color: _IntroPalette.platinum.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final slide = Curves.easeOutCubic.transform(
      math.max(0, math.min((progress - 0.32) / 0.38, 1.0)),
    );
    final opacity = Curves.easeOut.transform(
      math.max(0, math.min((progress - 0.28) / 0.32, 1.0)),
    );

    return Transform.translate(
      offset: Offset(0, (1 - slide) * 24),
      child: Opacity(
        opacity: opacity,
        child: Column(
          children: [
            Text(
              'RICO',
              style: TextStyle(
                fontSize: 18,
                letterSpacing: 12,
                fontWeight: FontWeight.w300,
                color: _IntroPalette.platinumMuted.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_IntroPalette.iceBlue, _IntroPalette.platinum],
              ).createShader(bounds),
              child: const Text(
                'INVESTIDOR',
                style: TextStyle(
                  fontSize: 34,
                  letterSpacing: 5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final opacity = Curves.easeOut.transform(
      math.max(0, math.min((progress - 0.46) / 0.3, 1.0)),
    );

    return Opacity(
      opacity: opacity,
      child: Text(
        'Mercados globais · Investir com classe',
        style: TextStyle(
          fontSize: 14,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500,
          color: _IntroPalette.silver.withValues(alpha: 0.75),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ChartPulse extends StatelessWidget {
  const _ChartPulse({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final draw = Curves.easeInOutCubic.transform(
      math.max(0, math.min((progress - 0.55) / 0.38, 1.0)),
    );

    return SizedBox(
      width: 220,
      height: 56,
      child: CustomPaint(
        painter: _ChartLinePainter(progress: draw),
      ),
    );
  }
}

class _ChartLinePainter extends CustomPainter {
  _ChartLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(0, size.height * 0.72),
      Offset(size.width * 0.18, size.height * 0.55),
      Offset(size.width * 0.34, size.height * 0.62),
      Offset(size.width * 0.52, size.height * 0.38),
      Offset(size.width * 0.68, size.height * 0.44),
      Offset(size.width * 0.84, size.height * 0.18),
      Offset(size.width, size.height * 0.28),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final metrics = path.computeMetrics().first;
    final extract = metrics.extractPath(0, metrics.length * progress);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = _IntroPalette.iceBlue.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(extract, glow);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [_IntroPalette.iceBlue, _IntroPalette.platinum],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(extract, line);
  }

  @override
  bool shouldRepaint(covariant _ChartLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

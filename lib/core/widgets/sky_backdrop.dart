import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Animated parallax sky backdrop — floating paper clouds + mountain
/// silhouettes + subtle star field.
///
/// Used by the Splash screen and the Main Menu so both share the same
/// living sky environment.
class SkyBackdrop extends StatefulWidget {
  const SkyBackdrop({super.key});

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<_CloudData> _clouds;

  static const _cloudCount = 8;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    final rng = math.Random(42);
    _clouds = List.generate(_cloudCount, (i) {
      return _CloudData(
        x: rng.nextDouble(),
        y: 0.05 + rng.nextDouble() * 0.45,
        scale: 0.5 + rng.nextDouble() * 0.8,
        speed: 0.015 + rng.nextDouble() * 0.025,
        opacity: 0.08 + rng.nextDouble() * 0.12,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SkyPainter(
            clouds: _clouds,
            animT: _controller.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CloudData {
  const _CloudData({
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.opacity,
    required this.phase,
  });

  final double x;
  final double y;
  final double scale;
  final double speed;
  final double opacity;
  final double phase;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.clouds, required this.animT});

  final List<_CloudData> clouds;
  final double animT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background gradient ───────────────────────────────────────────────
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.gradientTop, AppColors.background, AppColors.gradientBottom],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // ── Subtle star field ─────────────────────────────────────────────────
    final starRng = math.Random(77);
    final starPaint = Paint()..color = Colors.white.withOpacity(0.3);
    for (var i = 0; i < 50; i++) {
      final sx = starRng.nextDouble() * w;
      final sy = starRng.nextDouble() * h * 0.55;
      final sr = starRng.nextDouble() * 1.4 + 0.3;
      final twinkle =
          0.15 + 0.18 * math.sin(animT * math.pi * 2 + starRng.nextDouble() * 6);
      starPaint.color = Colors.white.withOpacity(twinkle.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(sx, sy), sr, starPaint);
    }

    // ── Paper clouds ──────────────────────────────────────────────────────
    for (final cloud in clouds) {
      final drift = (cloud.x + animT * cloud.speed * 4) % 1.2 - 0.1;
      final bobY = cloud.y + 0.012 * math.sin(animT * math.pi * 2 + cloud.phase);
      final cx = drift * w;
      final cy = bobY * h;
      final cloudScale = cloud.scale * w * 0.18;
      _drawPaperCloud(canvas, cx, cy, cloudScale, cloud.opacity);
    }

    // ── Parallax mountain silhouettes ─────────────────────────────────────
    final silColors = [
      AppColors.backgroundDeep,
      const Color(0xFF0E1630),
      const Color(0xFF151E3E),
    ];
    final silBases = [0.68, 0.74, 0.82];
    final parallaxSpeeds = [0.3, 0.6, 1.0];

    for (int layer = 0; layer < 3; layer++) {
      final offset = animT * parallaxSpeeds[layer] * 80;
      _drawMountainSilhouette(
        canvas,
        size,
        baseHeight: silBases[layer],
        color: silColors[layer],
        parallaxOffset: offset,
        seed: 10 + layer * 7,
        amplitude: 0.06 + layer * 0.02,
      );
    }
  }

  void _drawPaperCloud(Canvas canvas, double cx, double cy, double scale, double opacity) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: scale * 1.8, height: scale * 0.7),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - scale * 0.45, cy - scale * 0.15),
          width: scale * 1.0,
          height: scale * 0.6),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + scale * 0.4, cy - scale * 0.1),
          width: scale * 1.1,
          height: scale * 0.55),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + scale * 0.05, cy - scale * 0.3),
          width: scale * 0.9,
          height: scale * 0.5),
      paint,
    );
    final foldPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.3)
      ..strokeWidth = scale * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - scale * 0.7, cy + scale * 0.18),
      Offset(cx + scale * 0.7, cy + scale * 0.18),
      foldPaint,
    );
  }

  void _drawMountainSilhouette(
    Canvas canvas,
    Size size, {
    required double baseHeight,
    required Color color,
    required double parallaxOffset,
    required int seed,
    required double amplitude,
  }) {
    final w = size.width;
    final h = size.height;
    final rng = math.Random(seed);
    final paint = Paint()..color = color;
    final path = Path();
    final baseY = h * baseHeight;
    final peakAmp = h * amplitude;
    const numPeaks = 12;
    final segmentW = w / numPeaks;

    path.moveTo(0, h);
    path.lineTo(0, baseY);

    for (int i = 0; i <= numPeaks; i++) {
      final x = i * segmentW - (parallaxOffset % segmentW);
      final peakHeight = rng.nextDouble() * peakAmp;
      final isPeak = i % 2 == 0;
      final y = isPeak ? baseY - peakHeight : baseY - peakHeight * 0.3;
      if (i == 0) {
        path.lineTo(x.clamp(0.0, w + segmentW), y);
      } else {
        final ctrlX = x - segmentW * 0.5;
        final ctrlY = y - peakHeight * 0.4;
        path.quadraticBezierTo(ctrlX, ctrlY, x, y);
      }
    }

    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.animT != animT;
}

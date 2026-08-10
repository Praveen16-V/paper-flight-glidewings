import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../models/trial_definition.dart';
import '../providers/save_data_provider.dart';
import 'game_screen.dart';

/// Precision Trials hub — connected flight-path map across folded-paper islands.
class TrialsScreen extends ConsumerStatefulWidget {
  const TrialsScreen({super.key});

  @override
  ConsumerState<TrialsScreen> createState() => _TrialsScreenState();
}

class _TrialsScreenState extends ConsumerState<TrialsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dashCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _dashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _dashCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(saveDataProvider);

    // Build node data
    final nodes = <_TrialNodeData>[];
    for (var i = 0; i < TrialPool.all.length; i++) {
      final trial = TrialPool.all[i];
      final stars = ref.read(saveDataProvider.notifier).trialBestStars(trial.id);
      final previousStars = i == 0
          ? 1
          : ref.read(saveDataProvider.notifier).trialBestStars(TrialPool.all[i - 1].id);
      final unlocked = trial.isUnlockedBy(previousStars);
      nodes.add(_TrialNodeData(trial: trial, stars: stars, unlocked: unlocked));
    }

    // Find furthest unlocked for auto-scroll
    int furthest = 0;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].unlocked) furthest = i;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceAlt, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TitleBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Scroll to current position after first frame
                    const cardH = 118.0;
                    const verticalGap = 34.0;
                    const topPad = 18.0;
                    final targetScrollOffset = (topPad +
                            furthest * (cardH + verticalGap) +
                            cardH / 2 -
                            constraints.maxHeight / 2)
                        .clamp(0.0, double.infinity);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollCtrl.hasClients &&
                          _scrollCtrl.offset == 0 &&
                          targetScrollOffset > 0) {
                        _scrollCtrl.animateTo(
                          targetScrollOffset,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    });

                    return AnimatedBuilder(
                      animation: _dashCtrl,
                      builder: (context, _) {
                        return _FlightMap(
                          nodes: nodes,
                          dashPhase: _dashCtrl.value,
                          scrollCtrl: _scrollCtrl,
                          furthest: furthest,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrialNodeData {
  const _TrialNodeData({required this.trial, required this.stars, required this.unlocked});
  final TrialDefinition trial;
  final int stars;
  final bool unlocked;
}

class _FlightMap extends StatelessWidget {
  const _FlightMap({
    required this.nodes,
    required this.dashPhase,
    required this.scrollCtrl,
    required this.furthest,
  });
  final List<_TrialNodeData> nodes;
  final double dashPhase;
  final ScrollController scrollCtrl;
  final int furthest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Fix 1: wider cards — scale with screen width
      final cardW = (width * 0.52).clamp(160.0, 210.0);
      const cardH = 118.0;
      const verticalGap = 34.0;
      const horizontalInset = 12.0;
      const topPad = 18.0;
      const bottomPad = 28.0;

      final totalH = topPad + nodes.length * cardH + (nodes.length - 1) * verticalGap + bottomPad + 30;

      // compute island positions
      final centersY = <double>[];
      for (var i = 0; i < nodes.length; i++) {
        final y = topPad + i * (cardH + verticalGap) + cardH / 2;
        centersY.add(y);
      }

      return SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: width,
          height: totalH,
          child: Stack(
            children: [
              // dotted flight path behind islands
              Positioned.fill(
                child: CustomPaint(
                  painter: _FlightPathPainter(
                    nodes: nodes,
                    centersY: centersY,
                    cardW: cardW,
                    cardH: cardH,
                    inset: horizontalInset,
                    gap: verticalGap,
                    topPad: topPad,
                    dashPhase: dashPhase,
                    furthest: furthest,
                  ),
                ),
              ),
              // decorative floating clouds / wind swirls near path
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapDecorPainter(
                    centersY: centersY,
                    width: width,
                  ),
                ),
              ),
              // islands
              for (var i = 0; i < nodes.length; i++)
                Positioned(
                  left: i.isEven ? horizontalInset : null,
                  right: i.isOdd ? horizontalInset : null,
                  top: topPad + i * (cardH + verticalGap),
                  child: SizedBox(
                    width: cardW,
                    height: cardH,
                    child: _MapIsland(
                      data: nodes[i],
                      index: i,
                      isLeft: i.isEven,
                      onTap: nodes[i].unlocked
                          ? () => Navigator.of(context).pushNamed(
                                AppRoutes.game,
                                arguments: GameScreenArgs(mode: GameMode.trial, trialId: nodes[i].trial.id),
                              )
                          : null,
                    ),
                  ),
                ),
              // Fix 2: progress plane token — larger (40×40) with "YOU ARE HERE" label
              if (nodes.isNotEmpty)
                Positioned(
                  left: width / 2 - 20,
                  top: centersY[furthest] - 20,
                  child: _FlyingPlaneToken(
                    unlocked: nodes[furthest].unlocked,
                    stars: nodes[furthest].stars,
                  ),
                ),
              // legend footer
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 3, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        Text('UNLOCKED PATH', style: AppTypography.overline.copyWith(color: Colors.white.withOpacity(0.62), fontSize: 8, letterSpacing: 1.0)),
                        const SizedBox(width: 10),
                        Container(width: 12, height: 3, decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        Text('LOCKED', style: AppTypography.overline.copyWith(color: Colors.white.withOpacity(0.38), fontSize: 8, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _MapIsland extends StatelessWidget {
  const _MapIsland({
    required this.data,
    required this.index,
    required this.isLeft,
    required this.onTap,
  });
  final _TrialNodeData data;
  final int index;
  final bool isLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trial = data.trial;
    final stars = data.stars;
    final unlocked = data.unlocked;

    // checkpoint number
    final numStr = (index + 1).toString().padLeft(2, '0');
    final sheet = unlocked ? AppColors.paper : AppColors.paperWarm;
    final accent = _accentForBiome(trial.biome);

    return PaperCard(
      onTap: onTap,
      color: sheet,
      elevation: unlocked ? 1.4 : 0.7,
      padding: EdgeInsets.zero,
      radius: 16,
      borderColor: unlocked
          ? (stars >= 3 ? AppColors.warning : (stars >= 1 ? AppColors.success.withOpacity(0.85) : accent.withOpacity(0.55)))
          : null,
      borderWidth: stars >= 3 ? 1.8 : 1.3,
      dogEar: stars >= 3 ? const DogEar(label: '3★', color: AppColors.warning, size: 46) : null,
      child: Opacity(
        opacity: unlocked ? 1 : 0.68,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // top folded-paper island tab
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: unlocked ? accent.withOpacity(0.16) : AppColors.paperInkSoft.withOpacity(0.10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: unlocked ? accent.withOpacity(0.22) : Colors.black.withOpacity(0.06))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: unlocked ? accent : AppColors.paperInkSoft.withOpacity(0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
                      ),
                      child: Center(
                        child: Text(numStr,
                            style: const TextStyle(fontFamily: 'Fredoka', fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'CHECKPOINT $numStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.overline.copyWith(color: unlocked ? accent.withOpacity(0.95) : AppColors.paperInkSoft, fontSize: 8, letterSpacing: 1.0),
                      ),
                    ),
                    if (unlocked)
                      PaperIcon(PaperIconData.bullseye, size: 14, color: accent)
                    else
                      const Icon(Icons.lock, size: 12, color: AppColors.paperInkSoft),
                  ],
                ),
              ),
            ),
            // body
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 34, 10, 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trial.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(color: AppColors.paperInk, fontSize: 13.5, height: 1.0)),
                    const SizedBox(height: 2),
                    Text(trial.flavor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 9.5, height: 1.1)),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        for (int s = 1; s <= 3; s++)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(s <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 15, color: s <= stars ? AppColors.warning : AppColors.paperInkSoft.withOpacity(0.38)),
                          ),
                        const Spacer(),
                        if (trial.parSeconds != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.paperInk.withOpacity(0.06), borderRadius: BorderRadius.circular(5)),
                            child: Text('PAR ${trial.parSeconds!.toStringAsFixed(0)}s',
                                style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                          ),
                      ],
                    ),
                    // Fix 4: locked unlock hint
                    if (!unlocked && index > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Need ★ from checkpoint ${index.toString().padLeft(2, '0')}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.paperInkSoft.withOpacity(0.75),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (trial.totalCoins > 0) ...[
                          PaperIcon(PaperIconData.coin, size: 10, color: AppColors.coinGold),
                          const SizedBox(width: 3),
                          Text('${trial.totalCoins}', style: AppTypography.caption.copyWith(color: AppColors.coinGoldDeep, fontSize: 10, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(trial.objective,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft.withOpacity(0.85), fontSize: 8.5, fontStyle: FontStyle.italic)),
                        ),
                        const SizedBox(width: 6),
                        Icon(unlocked ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded,
                            color: unlocked ? accent : AppColors.paperInkSoft.withOpacity(0.55), size: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // connector nub toward center spine
            Positioned(
              top: 54,
              left: isLeft ? null : -10,
              right: isLeft ? -10 : null,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: unlocked ? accent : AppColors.paperInkSoft.withOpacity(0.32),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.6),
                  boxShadow: [BoxShadow(color: (unlocked ? accent : Colors.black).withOpacity(0.18), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accentForBiome(Biome b) {
    switch (b) {
      case Biome.city:
        return AppColors.accent;
      case Biome.mountain:
        return const Color(0xFF81C784);
      case Biome.backyard:
        return const Color(0xFF4FC3F7);
      case Biome.storm:
        return const Color(0xFF90A4AE);
      default:
        return AppColors.accent;
    }
  }
}

class _FlyingPlaneToken extends StatelessWidget {
  const _FlyingPlaneToken({required this.unlocked, required this.stars});
  final bool unlocked;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: unlocked ? AppColors.accent : AppColors.paperInkSoft.withOpacity(0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              if (unlocked) ...[
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.flight_rounded, size: 20, color: Colors.white),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.backgroundDeep.withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'YOU ARE HERE',
            style: AppTypography.overline.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 6,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlightPathPainter extends CustomPainter {
  _FlightPathPainter({
    required this.nodes,
    required this.centersY,
    required this.cardW,
    required this.cardH,
    required this.inset,
    required this.gap,
    required this.topPad,
    required this.dashPhase,
    required this.furthest,
  });
  final List<_TrialNodeData> nodes;
  final List<double> centersY;
  final double cardW;
  final double cardH;
  final double inset;
  final double gap;
  final double topPad;
  final double dashPhase;
  final int furthest;

  @override
  void paint(Canvas canvas, Size size) {
    final spineX = size.width / 2;
    final dashLen = 7.0;
    final dashGap = 6.0;
    final phase = dashPhase * (dashLen + dashGap);

    // spine segments between island centers
    for (var i = 0; i < nodes.length - 1; i++) {
      final y0 = centersY[i];
      final y1 = centersY[i + 1];
      final segmentUnlocked = nodes[i + 1].unlocked;
      final paint = Paint()
        ..color = segmentUnlocked ? AppColors.accent.withOpacity(0.92) : Colors.white.withOpacity(0.20)
        ..strokeWidth = segmentUnlocked ? 2.8 : 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (segmentUnlocked) {
        _drawDashedLine(canvas, Offset(spineX, y0), Offset(spineX, y1), paint, dashLen, dashGap, phase);
        // glow under unlocked spine
        final glow = Paint()
          ..color = AppColors.accent.withOpacity(0.18)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
        _drawDashedLine(canvas, Offset(spineX, y0), Offset(spineX, y1), glow, dashLen, dashGap, phase);
      } else {
        // faint static dashed
        _drawDashedLine(canvas, Offset(spineX, y0), Offset(spineX, y1), paint, 4, 7, 0);
      }
    }

    // stubs from each island nub to spine
    for (var i = 0; i < nodes.length; i++) {
      final isLeft = i.isEven;
      final y = centersY[i];
      final islandInnerX = isLeft ? inset + cardW : size.width - inset - cardW;
      final unlocked = nodes[i].unlocked;
      final paint = Paint()
        ..color = unlocked ? AppColors.accent.withOpacity(0.88) : Colors.white.withOpacity(0.14)
        ..strokeWidth = unlocked ? 2.2 : 1.3
        ..strokeCap = StrokeCap.round;
      final start = Offset(islandInnerX, y);
      final end = Offset(spineX, y);
      if (unlocked) {
        _drawDashedLine(canvas, start, end, paint, dashLen, dashGap, phase);
      } else {
        _drawDashedLine(canvas, start, end, paint, 4, 7, 0);
      }

      // checkpoint dot on spine
      final dotY = y;
      final isDone = nodes[i].stars >= 1;
      final dotUnlocked = nodes[i].unlocked;
      // outer ring
      canvas.drawCircle(
          Offset(spineX, dotY),
          9,
          Paint()
            ..color = Colors.white.withOpacity(dotUnlocked ? 0.95 : 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
      // inner fill
      Color fill;
      if (!dotUnlocked) {
        fill = AppColors.paperInkSoft.withOpacity(0.35);
      } else if (isDone) {
        fill = nodes[i].stars >= 3 ? AppColors.warning : AppColors.success;
      } else {
        fill = AppColors.accent.withOpacity(0.92);
      }
      canvas.drawCircle(Offset(spineX, dotY), 5.5, Paint()..color = fill);
      if (isDone) {
        canvas.drawCircle(Offset(spineX, dotY), 2.4, Paint()..color = Colors.white.withOpacity(0.92));
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint, double dashLen, double dashGap, double phase) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    double dist = -phase % (dashLen + dashGap);
    // normalize negative modulo
    dist = dist < 0 ? dist + dashLen + dashGap : dist;
    // start before a to account phase
    double pos = -phase;
    while (pos < total) {
      final segStart = a + dir * pos.clamp(0, total);
      final segEnd = a + dir * (pos + dashLen).clamp(0, total);
      if (pos + dashLen > 0 && pos < total) {
        canvas.drawLine(segStart, segEnd, paint);
      }
      pos += dashLen + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _FlightPathPainter old) =>
      old.dashPhase != dashPhase || old.nodes != nodes || old.furthest != furthest;
}

class _MapDecorPainter extends CustomPainter {
  _MapDecorPainter({required this.centersY, required this.width});
  final List<double> centersY;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.07);
    final outline = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final rnd = math.Random(42);
    for (var i = 0; i < centersY.length; i++) {
      final y = centersY[i];
      // two faint clouds near spine
      for (var k = 0; k < 2; k++) {
        final cx = width / 2 + (rnd.nextDouble() * 90 - 45) + (k == 0 ? -70 : 70) * 0.35;
        final cy = y + rnd.nextDouble() * 24 - 12;
        final r = 10 + rnd.nextDouble() * 8;
        // puff cluster
        canvas.drawCircle(Offset(cx, cy), r, cloudPaint);
        canvas.drawCircle(Offset(cx + r * 0.5, cy - 2), r * 0.7, cloudPaint);
        canvas.drawCircle(Offset(cx - r * 0.45, cy + 1), r * 0.6, cloudPaint);
        canvas.drawCircle(Offset(cx, cy), r, outline);
      }
      // wind swirl near gap midpoint if not last
      if (i < centersY.length - 1) {
        final my = (centersY[i] + centersY[i + 1]) / 2;
        final swirlX = width / 2 + (i.isEven ? 26 : -26);
        final path = Path();
        path.moveTo(swirlX, my - 7);
        path.quadraticBezierTo(swirlX + 8, my, swirlX, my + 7);
        canvas.drawPath(path, outline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapDecorPainter old) => false;
}

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text('PRECISION TRIALS',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium.copyWith(fontSize: 22, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text('Follow the folded path  •  earn your wings',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, letterSpacing: 0.4)),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_icons.dart';
import '../models/save_data.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';
import 'splash_screen.dart'; // reuse PaperPlaneIcon

/// Main menu — under 2 taps from app open to flying (per GDD §11).
/// Layout: logo top-third, PLAY CTA center, nav row bottom.
///
/// UI/UX improvements applied:
///  • Animated parallax sky silhouette with floating paper clouds
///  • Glassmorphic currency badges with glow accents
///  • Mode Preview Card (miniature mode selector) replacing the flat "MORE MODES" pill
///  • Selected-state indicator pills on the bottom navigation bar
class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatAnim;
  late Animation<double> _floatY;

  /// Tracks the selected game mode index for the Mode Preview Card carousel.
  int _selectedModeIndex = 0;

  /// The currently highlighted bottom-nav tab index.
  int _activeNavIndex = -1;

  @override
  void initState() {
    super.initState();
    _floatAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatAnim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Animated parallax sky backdrop ──────────────────────────────
          const Positioned.fill(child: _ParallaxSkyBackdrop()),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top: glassmorphic currency strip ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _GlassCurrencyBadge(
                        glowColor: AppColors.coinGold,
                        child: CoinChip(
                          save.coins,
                          iconSize: 18,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _GlassCurrencyBadge(
                        glowColor: AppColors.gemBlue,
                        child: GemChip(
                          save.gems,
                          iconSize: 16,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Centre: logo + plane ──────────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _floatY,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _floatY.value),
                          child: PaperPlaneIcon(size: 100),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'PAPER FLIGHT',
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 34,
                          letterSpacing: 3,
                        ),
                      ),
                      if (save.highScore > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BEST',
                                style: AppTypography.overline.copyWith(
                                  color: AppColors.paperInkSoft,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(save.highScore),
                                style: AppTypography.statSmall.copyWith(
                                  color: AppColors.accentDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // ── Mode Preview Card (replaces _ModesPill) ─────────
                      _ModePreviewCard(
                        selectedIndex: _selectedModeIndex,
                        save: save,
                        onTapLeft: () => setState(() {
                          _selectedModeIndex =
                              (_selectedModeIndex - 1).clamp(
                                  0, _ModePreviewCard.modeCount - 1);
                        }),
                        onTapRight: () => setState(() {
                          _selectedModeIndex =
                              (_selectedModeIndex + 1).clamp(
                                  0, _ModePreviewCard.modeCount - 1);
                        }),
                        onTapCenter: _onModeTap,
                      ),
                      const SizedBox(height: 20),

                      // ── PLAY button ──────────────────────────────────────
                      _PlayButton(onTap: _onPlay),
                    ],
                  ),
                ),

                // ── Bottom nav bar with selected-state pills ──────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavIcon(
                        icon: Icons.airplanemode_active,
                        label: 'Hangar',
                        isActive: _activeNavIndex == 0,
                        onTap: () {
                          setState(() => _activeNavIndex = 0);
                          Navigator.pushNamed(context, AppRoutes.hangar);
                        },
                      ),
                      _NavIcon(
                        icon: Icons.storefront_outlined,
                        label: 'Shop',
                        isActive: _activeNavIndex == 1,
                        onTap: () {
                          setState(() => _activeNavIndex = 1);
                          Navigator.pushNamed(context, AppRoutes.shop);
                        },
                      ),
                      _NavIcon(
                        icon: Icons.emoji_events_outlined,
                        label: 'Challenges',
                        isActive: _activeNavIndex == 2,
                        onTap: () {
                          setState(() => _activeNavIndex = 2);
                          Navigator.pushNamed(
                              context, AppRoutes.dailyChallenges);
                        },
                      ),
                      _NavIcon(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        isActive: _activeNavIndex == 3,
                        onTap: () {
                          setState(() => _activeNavIndex = 3);
                          Navigator.pushNamed(context, AppRoutes.settings);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onPlay() {
    AnalyticsService.instance.logEvent('play_tapped');
    Navigator.of(context).pushNamed(AppRoutes.game);
  }

  void _onModeTap() {
    AnalyticsService.instance.logEvent('modes_tapped');
    Navigator.of(context).pushNamed(AppRoutes.modes);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Animated Parallax Sky Backdrop ─────────────────────────────────────────────

/// Floating paper clouds with layered parallax silhouettes that animate slowly,
/// giving the main menu an alive, breathing sky environment.
class _ParallaxSkyBackdrop extends StatefulWidget {
  const _ParallaxSkyBackdrop();

  @override
  State<_ParallaxSkyBackdrop> createState() => _ParallaxSkyBackdropState();
}

class _ParallaxSkyBackdropState extends State<_ParallaxSkyBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// Procedurally generated cloud data.
  static const _cloudCount = 8;
  late final List<_CloudData> _clouds;

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
        final t = _controller.value; // 0→1 over 20s loop
        return CustomPaint(
          painter: _SkyPainter(
            clouds: _clouds,
            animT: t,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CloudData {
  final double x;
  final double y;
  final double scale;
  final double speed;
  final double opacity;
  final double phase;

  _CloudData({
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.clouds, required this.animT});

  final List<_CloudData> clouds;
  final double animT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Subtle star field ─────────────────────────────────────────────────
    final starRng = math.Random(77);
    final starPaint = Paint()..color = Colors.white.withOpacity(0.3);
    for (var i = 0; i < 40; i++) {
      final sx = starRng.nextDouble() * w;
      final sy = starRng.nextDouble() * h * 0.5;
      final sr = starRng.nextDouble() * 1.2 + 0.3;
      // Twinkle: modulate opacity by sin wave
      final twinkle = 0.15 +
          0.15 * math.sin(animT * math.pi * 2 + starRng.nextDouble() * 6);
      starPaint.color = Colors.white.withOpacity(twinkle);
      canvas.drawCircle(Offset(sx, sy), sr, starPaint);
    }

    // ── Paper clouds (origami-shaped, drifting) ───────────────────────────
    for (final cloud in clouds) {
      // Drift horizontally; wrap around.
      final drift = (cloud.x + animT * cloud.speed * 4) % 1.2 - 0.1;
      // Gentle vertical bob.
      final bobY = cloud.y +
          0.012 * math.sin(animT * math.pi * 2 + cloud.phase);
      final cx = drift * w;
      final cy = bobY * h;
      final cloudScale = cloud.scale * w * 0.18;

      _drawPaperCloud(canvas, cx, cy, cloudScale, cloud.opacity);
    }

    // ── Parallax mountain silhouettes ─────────────────────────────────────
    // Three layers, each progressively lighter and closer (higher).
    final silColors = [
      AppColors.backgroundDeep,            // furthest, darkest
      const Color(0xFF0E1630),             // mid
      const Color(0xFF151E3E),             // nearest, lightest
    ];
    final silBases = [
      0.68, // start height (fraction of h)
      0.74,
      0.82,
    ];
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

  void _drawPaperCloud(
      Canvas canvas, double cx, double cy, double scale, double opacity) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity);

    // Origami cloud: 3 overlapping ellipses with a flat bottom (paper fold)
    // Main body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: scale * 1.8,
        height: scale * 0.7,
      ),
      paint,
    );
    // Left puff
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - scale * 0.45, cy - scale * 0.15),
        width: scale * 1.0,
        height: scale * 0.6,
      ),
      paint,
    );
    // Right puff
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + scale * 0.4, cy - scale * 0.1),
        width: scale * 1.1,
        height: scale * 0.55,
      ),
      paint,
    );
    // Top puff
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + scale * 0.05, cy - scale * 0.3),
        width: scale * 0.9,
        height: scale * 0.5,
      ),
      paint,
    );
    // Flat bottom fold (paper crease line)
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

    path.moveTo(0, h);
    path.lineTo(0, baseY);

    // Generate peaks using deterministic random
    final numPeaks = 12;
    final segmentW = w / numPeaks;
    for (int i = 0; i <= numPeaks; i++) {
      final x = i * segmentW - (parallaxOffset % segmentW);
      final peakHeight = rng.nextDouble() * peakAmp;
      final isPeak = i % 2 == 0;
      final y = isPeak ? baseY - peakHeight : baseY - peakHeight * 0.3;
      if (i == 0) {
        path.lineTo(x.clamp(0.0, w + segmentW), y);
      } else {
        // Smooth peaks with quadratic bezier
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

// ── Glassmorphic Currency Badge ────────────────────────────────────────────────

/// Glassmorphic badge for the currency display. Semi-transparent dark backdrop
/// with a subtle inner border and a soft glow around the icon colour.
class _GlassCurrencyBadge extends StatelessWidget {
  const _GlassCurrencyBadge({
    required this.child,
    required this.glowColor,
  });

  final Widget child;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        // Semi-transparent dark glass
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface.withOpacity(0.75),
            AppColors.background.withOpacity(0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        // 1px inner border (light stroke to simulate glass edge)
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
        // Outer glow in the colour of the icon
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: -1,
          ),
          // Subtle inner highlight
          BoxShadow(
            color: Colors.white.withOpacity(0.04),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Mode Preview Card ──────────────────────────────────────────────────────────

/// Interactive miniature mode selector that displays the currently selected
/// mode's name, paper-craft icon, tagline, and personal best score. Arrow
/// buttons cycle through modes; tapping the centre opens the full Modes screen.
class _ModePreviewCard extends StatelessWidget {
  const _ModePreviewCard({
    required this.selectedIndex,
    required this.save,
    required this.onTapLeft,
    required this.onTapRight,
    required this.onTapCenter,
  });

  final int selectedIndex;
  final SaveData save;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;
  final VoidCallback onTapCenter;

  /// The four game modes in display order.
  static const modeCount = 4;

  static const _modes = <_ModeInfo>[
    _ModeInfo(
      name: 'Classic Flight',
      tagline: 'Endless arcade',
      iconData: PaperIconData.glider,
      accent: AppColors.accent,
      paperColor: AppColors.paperGold,
    ),
    _ModeInfo(
      name: 'Zen Flight',
      tagline: 'No crashes. Just glide.',
      iconData: PaperIconData.leaf,
      accent: AppColors.success,
      paperColor: AppColors.paperGreen,
    ),
    _ModeInfo(
      name: 'Daily Seeded',
      tagline: 'One run a day',
      iconData: PaperIconData.calendar,
      accent: AppColors.accentAlt,
      paperColor: AppColors.paperBlue,
    ),
    _ModeInfo(
      name: 'Precision Trial',
      tagline: 'Earn your stars',
      iconData: PaperIconData.bullseye,
      accent: AppColors.danger,
      paperColor: AppColors.paperRose,
    ),
  ];

  String _bestScoreText(int index) {
    switch (index) {
      case 0: // Classic
        return 'Best: ${_fmt(save.highScore)}';
      case 1: // Zen
        final d = save.zenBestDistanceMeters;
        return d > 0 ? 'Best: ${d.toStringAsFixed(0)}m' : 'Not played yet';
      case 2: // Daily
        return 'Today\'s run';
      case 3: // Trial
        final total = save.trialStars.fold<int>(0, (sum, s) => sum + s);
        return total > 0 ? '\u2605 $total earned' : 'Not started';
      default:
        return '';
    }
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _modes[selectedIndex];

    return SizedBox(
      width: 260,
      child: Row(
        children: [
          // ── Left arrow ──────────────────────────────────────────────────
          GestureDetector(
            onTap: selectedIndex > 0 ? onTapLeft : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selectedIndex > 0
                    ? AppColors.surface.withOpacity(0.7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedIndex > 0
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.chevron_left,
                color: selectedIndex > 0
                    ? AppColors.textLight
                    : AppColors.textMuted.withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // ── Centre: mode info card ──────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onTapCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                key: ValueKey(selectedIndex),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: mode.paperColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: mode.accent.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      // Paper fold shadow beneath
                      BoxShadow(
                        color: _darken(mode.accent, 0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: mode.accent.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Mode icon medallion
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: mode.accent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _darken(mode.accent, 0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: PaperIcon(
                            mode.iconData,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mode.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: _darken(mode.accent, 0.3),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _bestScoreText(selectedIndex),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.paperInkSoft,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: _darken(mode.accent, 0.2),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // ── Right arrow ─────────────────────────────────────────────────
          GestureDetector(
            onTap: selectedIndex < modeCount - 1 ? onTapRight : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selectedIndex < modeCount - 1
                    ? AppColors.surface.withOpacity(0.7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedIndex < modeCount - 1
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.chevron_right,
                color: selectedIndex < modeCount - 1
                    ? AppColors.textLight
                    : AppColors.textMuted.withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Immutable mode descriptor for the preview card.
class _ModeInfo {
  final String name;
  final String tagline;
  final PaperIconData iconData;
  final Color accent;
  final Color paperColor;

  const _ModeInfo({
    required this.name,
    required this.tagline,
    required this.iconData,
    required this.accent,
    required this.paperColor,
  });
}

// ── Play Button (unchanged) ────────────────────────────────────────────────────

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: PaperButton(
        label: 'PLAY',
        onPressed: widget.onTap,
        color: const Color(0xFFF5A623),
      ),
    );
  }
}

// ── Navigation Icon with Selected-State Indicator ──────────────────────────────

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accent : AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? AppColors.accentDeep
                        : const Color(0xFFB89E6E),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                  if (isActive)
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                ],
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : AppColors.paperInk,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isActive ? AppColors.accent : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            // ── Selected-state origami underline / pill indicator ──────────
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: isActive ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: -1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

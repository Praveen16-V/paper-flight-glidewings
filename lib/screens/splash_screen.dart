import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/widgets/sky_backdrop.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';

/// Shown for ~1.8s on cold launch.
/// Simultaneously: loads save data, claims daily login reward, navigates.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;

  bool _loadingVisible = false;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _scaleIn = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );

    _anim.forward();
    _init();
  }

  Future<void> _init() async {
    // Show loading dots after brand animation completes.
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _loadingVisible = true);

    // Claim daily reward silently.
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      final reward =
          await ref.read(saveDataProvider.notifier).claimDailyLoginReward();
      if (reward > 0) {
        AnalyticsService.instance.logEvent('daily_login_reward',
            params: {'coins': reward});
      }
    }

    // Hide loading dots just before navigation.
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loadingVisible = false);

    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.mainMenu);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Shared animated sky backdrop ──────────────────────────────
          const SkyBackdrop(),

          // ── Brand content ─────────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing plane icon
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.38),
                            blurRadius: 48,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: PaperPlaneIcon(size: 140),
                    ),
                    const SizedBox(height: 28),
                    // Title
                    Text(
                      'PAPER FLIGHT',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 42,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tagline
                    Text(
                      'catch the wind',
                      style: AppTypography.caption.copyWith(
                        fontSize: 15,
                        letterSpacing: 4,
                        color: AppColors.textLight.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Loading dots ──────────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _loadingVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: const _LoadingDots(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three pulsing dots that stagger their opacity to indicate loading.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            // Each dot leads by 0.2 phase
            final phase = (i * 0.28);
            final t = (_ctrl.value + phase) % 1.0;
            final opacity = 0.25 + 0.75 * (0.5 + 0.5 * (1.0 - (t * 2 - 1).abs()));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(opacity.clamp(0.25, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Vector paper plane icon — no asset dependency.
class PaperPlaneIcon extends StatelessWidget {
  const PaperPlaneIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.7),
      painter: PlanePainter(),
    );
  }
}

class PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x44000000)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Shadow
    canvas.save();
    canvas.translate(4, 5);
    _drawPlane(canvas, shadowPaint, w, h);
    canvas.restore();

    _drawPlane(canvas, paint, w, h);

    // Highlight fold line
    final foldPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.1, h * 0.5),
      Offset(w * 0.7, h * 0.5),
      foldPaint,
    );
  }

  void _drawPlane(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(w, h / 2)
      ..lineTo(0, 0)
      ..lineTo(w * 0.25, h / 2)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PlanePainter old) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
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
    // Small delay to let the first frame paint before doing any work.
    await Future.delayed(const Duration(milliseconds: 200));

    // Claim daily reward silently — fail soft if persistence isn't ready yet.
    if (mounted) {
      try {
        final reward =
            await ref.read(saveDataProvider.notifier).claimDailyLoginReward();
        if (reward > 0) {
          AnalyticsService.instance.logEvent('daily_login_reward',
              params: {'coins': reward});
        }
      } catch (e) {
        debugPrint('Daily reward claim skipped: $e');
      }
    }

    // Minimum splash hold — total ~2s from launch including the 200ms above.
    await Future.delayed(const Duration(milliseconds: 1600));
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
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scaleIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo placeholder — replace with Image.asset when art is ready.
                PaperPlaneIcon(size: 120),
                const SizedBox(height: 24),
                const Text(
                  'PAPER FLIGHT',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'catch the wind',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_icons.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';
import 'splash_screen.dart'; // reuse PaperPlaneIcon

/// Main menu — under 2 taps from app open to flying (per GDD §11).
/// Layout: logo top-third, PLAY CTA center, nav row bottom.
class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatAnim;
  late Animation<double> _floatY;

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceAlt, AppColors.backgroundDeep],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top: currency strip ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DarkCurrencyChip(
                      child: CoinChip(save.coins, iconSize: 18, fontSize: 15),
                    ),
                    const SizedBox(width: 10),
                    _DarkCurrencyChip(
                      child: GemChip(save.gems, iconSize: 16, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // ── Centre: logo + plane ──────────────────────────────────────
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
                    const SizedBox(height: 40),

                    // ── PLAY button ────────────────────────────────────────
                    _PlayButton(onTap: _onPlay),
                    const SizedBox(height: 16),

                    // ── Game modes hub ─────────────────────────────────────
                    _ModesPill(onTap: _onModes),
                  ],
                ),
              ),

              // ── Bottom nav bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavIcon(
                      icon: Icons.airplanemode_active,
                      label: 'Hangar',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.hangar),
                    ),
                    _NavIcon(
                      icon: Icons.storefront_outlined,
                      label: 'Shop',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.shop),
                    ),
                    _NavIcon(
                      icon: Icons.emoji_events_outlined,
                      label: 'Challenges',
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.dailyChallenges),
                    ),
                    _NavIcon(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.settings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPlay() {
    AnalyticsService.instance.logEvent('play_tapped');
    Navigator.of(context).pushNamed(AppRoutes.game);
  }

  void _onModes() {
    AnalyticsService.instance.logEvent('modes_tapped');
    Navigator.of(context).pushNamed(AppRoutes.modes);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Small dark translucent chip used for currency on the dark menu backdrop.
class _DarkCurrencyChip extends StatelessWidget {
  const _DarkCurrencyChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withOpacity(0.6)),
      ),
      child: child,
    );
  }
}

class _ModesPill extends StatelessWidget {
  const _ModesPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.paperWarm,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperIcon(PaperIconData.leaf, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'MORE MODES',
              style: AppTypography.overline.copyWith(
                color: AppColors.paperInk,
                fontSize: 11,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 8),
            PaperIcon(PaperIconData.bullseye, size: 16, color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}

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

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFB89E6E),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.paperInk, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            // ── Top: currency strip ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CurrencyChip(
                    value: save.coins,
                    color: AppColors.coinGold,
                    icon: '●',
                  ),
                  const SizedBox(width: 10),
                  _CurrencyChip(
                    value: save.gems,
                    color: AppColors.gemBlue,
                    icon: '◆',
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
                  const Text(
                    'PAPER FLIGHT',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  if (save.highScore > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'BEST  ${_fmt(save.highScore)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),

                  // ── PLAY button ────────────────────────────────────────
                  _PlayButton(onTap: _onPlay),
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
                    onTap: () => Navigator.pushNamed(context, AppRoutes.hangar),
                  ),
                  _NavIcon(
                    icon: Icons.storefront_outlined,
                    label: 'Shop',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.shop),
                  ),
                  _NavIcon(
                    icon: Icons.emoji_events_outlined,
                    label: 'Challenges',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.dailyChallenges),
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
    );
  }

  void _onPlay() {
    AnalyticsService.instance.logEvent('play_tapped');
    Navigator.of(context).pushNamed(AppRoutes.game);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
      duration: const Duration(milliseconds: 900),
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 220,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5A623), Color(0xFFFF6B35)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'PLAY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
          ),
        ),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(icon, color: AppColors.textLight, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.value,
    required this.color,
    required this.icon,
  });
  final int value;
  final Color color;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

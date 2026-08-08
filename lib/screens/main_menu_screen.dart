import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_typography.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/sky_backdrop.dart';
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
          const Positioned.fill(child: SkyBackdrop()),

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
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.backgroundDeep.withOpacity(0.55),
                                offset: const Offset(0, 3),
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
          // ── Left arrow — 44×44 touch target ─────────────────────────────
          GestureDetector(
            onTap: selectedIndex > 0 ? onTapLeft : null,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
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
                    size: 22,
                  ),
                ),
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
                        width: 44,
                        height: 44,
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
                            size: 24,
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

          // ── Right arrow — 44×44 touch target ────────────────────────────
          GestureDetector(
            onTap: selectedIndex < modeCount - 1 ? onTapRight : null,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
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
                    size: 22,
                  ),
                ),
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
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
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
                fontSize: 11.5,
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

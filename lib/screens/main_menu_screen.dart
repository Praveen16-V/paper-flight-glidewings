import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/currency_badge.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/how_to_play_dialog.dart';
import '../core/widgets/mode_card.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_effects.dart';
import '../core/widgets/paper_icons.dart';
import '../core/widgets/sky_backdrop.dart';
import '../l10n/app_localizations.dart';
import '../models/save_data.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';
import '../services/onboarding_service.dart';
import 'game_screen.dart';
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
  bool _firstRunGuideScheduled = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstRunGuide());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _floatAnim.stop();
      _floatAnim.value = 0.5;
    } else if (!_floatAnim.isAnimating) {
      _floatAnim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final strings = context.l10n;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compact = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: SkyBackdrop()),
          SafeArea(
            minimum: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                // Help remains visible without competing with the currencies.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 16, 0),
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: strings.text('menu.howToPlay'),
                        child: IconButton(
                          onPressed: _openGuide,
                          tooltip: strings.text('menu.howToPlay'),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.surface.withOpacity(0.78),
                            foregroundColor: AppColors.textLight,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          icon: const Icon(Icons.help_outline_rounded),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          reverse: true,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CurrencyBadge(
                                glowColor: AppColors.coinGold,
                                child: CoinChip(
                                  save.coins,
                                  iconSize: 18,
                                  fontSize: 15,
                                  color: AppColors.coinGoldDeep,
                                ),
                              ),
                              const SizedBox(width: 8),
                              CurrencyBadge(
                                glowColor: AppColors.gemBlue,
                                child: GemChip(
                                  save.gems,
                                  iconSize: 16,
                                  fontSize: 14,
                                  color: AppColors.gemBlueDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Never scale text down to force a fit. Short displays and
                // large accessibility text can scroll this central funnel.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: compact ? 4 : 10,
                        ),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _floatY,
                                  builder: (_, __) => Transform.translate(
                                    offset: Offset(0, _floatY.value),
                                    child: PaperPlaneIcon(
                                      size: compact ? 72 : 96,
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 8 : 16),
                                Text(
                                  strings.text('menu.title'),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.displayMedium.copyWith(
                                    fontSize: compact ? 29 : 34,
                                    letterSpacing: 2.4,
                                  ),
                                ),
                                if (save.highScore > 0) ...[
                                  const SizedBox(height: 8),
                                  Semantics(
                                    label:
                                        '${strings.text('menu.best')} ${save.highScore}',
                                    child: ExcludeSemantics(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.paper,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.backgroundDeep
                                                  .withOpacity(0.55),
                                              offset: const Offset(0, 3),
                                              blurRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              strings.text('menu.best'),
                                              style: AppTypography.overline
                                                  .copyWith(
                                                color:
                                                    AppColors.paperInkSoft,
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _fmt(save.highScore),
                                              style: AppTypography.statSmall
                                                  .copyWith(
                                                color: AppColors.accentDeep,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: compact ? 16 : 26),
                                _ModePreviewCard(
                                  selectedIndex: _selectedModeIndex,
                                  save: save,
                                  onTapLeft: () => setState(() {
                                    _selectedModeIndex =
                                        (_selectedModeIndex - 1)
                                            .clamp(
                                              0,
                                              _ModePreviewCard.modeCount - 1,
                                            )
                                            .toInt();
                                  }),
                                  onTapRight: () => setState(() {
                                    _selectedModeIndex =
                                        (_selectedModeIndex + 1)
                                            .clamp(
                                              0,
                                              _ModePreviewCard.modeCount - 1,
                                            )
                                            .toInt();
                                  }),
                                  onTapCenter: _onModeTap,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  strings.text('menu.allModesHint'),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSubtle,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: compact ? 12 : 18),
                                _PlayButton(
                                  label: _playLabel(strings),
                                  onTap: _onPlay,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // A horizontal fallback protects very narrow split-screen
                // layouts while preserving 48 px targets and full text labels.
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(
                        8,
                        0,
                        8,
                        compact ? 10 : 18,
                      ),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth - 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NavIcon(
                              icon: Icons.airplanemode_active,
                              label: strings.text('menu.hangar'),
                              isActive: _activeNavIndex == 0,
                              onTap: () {
                                setState(() => _activeNavIndex = 0);
                                Navigator.pushNamed(context, AppRoutes.hangar);
                              },
                            ),
                            _NavIcon(
                              icon: Icons.storefront_outlined,
                              label: strings.text('menu.shop'),
                              isActive: _activeNavIndex == 1,
                              onTap: () {
                                setState(() => _activeNavIndex = 1);
                                Navigator.pushNamed(context, AppRoutes.shop);
                              },
                            ),
                            _NavIcon(
                              icon: Icons.emoji_events_outlined,
                              label: strings.text('menu.challenges'),
                              isActive: _activeNavIndex == 2,
                              onTap: () {
                                setState(() => _activeNavIndex = 2);
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.dailyChallenges,
                                );
                              },
                            ),
                            _NavIcon(
                              icon: Icons.settings_outlined,
                              label: strings.text('menu.settings'),
                              isActive: _activeNavIndex == 3,
                              onTap: () {
                                setState(() => _activeNavIndex = 3);
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.settings,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _playLabel(AppLocalizations strings) {
    return strings.text(switch (_selectedModeIndex) {
      0 => 'menu.playClassic',
      1 => 'menu.startZen',
      2 => 'menu.viewDaily',
      _ => 'menu.chooseTrial',
    });
  }

  Future<void> _showFirstRunGuide() async {
    if (!mounted || _firstRunGuideScheduled) return;
    _firstRunGuideScheduled = true;
    if (OnboardingService.instance.hasCompletedTutorial) return;
    // Do not force a newly-added tutorial on established installs. It remains
    // available from the persistent help button.
    if (!ref.read(saveDataProvider).isFirstSession) {
      await OnboardingService.instance.completeTutorial();
      return;
    }
    await showHowToPlayDialog(
      context,
      firstRun: true,
      surface: 'first_run_menu',
    );
  }

  void _openGuide() {
    showHowToPlayDialog(context, surface: 'main_menu');
  }

  void _onPlay() {
    final mode = GameMode.values[_selectedModeIndex];
    AnalyticsService.instance.logModeSelected(mode, source: 'main_menu_play');
    switch (mode) {
      case GameMode.classic:
      case GameMode.zen:
        Navigator.of(context).pushNamed(
          AppRoutes.game,
          arguments: GameScreenArgs(mode: mode),
        );
        break;
      case GameMode.daily:
        Navigator.of(context).pushNamed(AppRoutes.dailyFlight);
        break;
      case GameMode.trial:
        Navigator.of(context).pushNamed(AppRoutes.trials);
        break;
    }
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

// ── Mode Preview Card ──────────────────────────────────────────────────────────

/// Interactive miniature mode selector that displays the currently selected
/// mode's name, paper-craft icon, tagline, and personal best score.
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

  static int get modeCount => ModePresentation.all.length;

  String _bestScoreText(BuildContext context, int index) {
    final strings = context.l10n;
    switch (index) {
      case 0:
        return strings.text('mode.bestScore', {'score': _fmt(save.highScore)});
      case 1:
        final d = save.zenBestDistanceMeters;
        return d > 0
            ? strings.text(
                'mode.bestDistance',
                {'distance': d.toStringAsFixed(0)},
              )
            : strings.text('mode.notPlayed');
      case 2:
        return strings.text('mode.todaysRun');
      case 3:
        final total = save.trialStars.fold<int>(0, (sum, s) => sum + s);
        return total > 0
            ? strings.text('mode.starsEarned', {'stars': total})
            : strings.text('mode.notStarted');
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
    final presentation = ModePresentation.atIndex(selectedIndex);
    final strings = context.l10n;
    final modeName = strings.text(presentation.nameKey);
    final availableWidth = MediaQuery.sizeOf(context).width - 24;

    return SizedBox(
      width: availableWidth.clamp(240.0, 330.0).toDouble(),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: selectedIndex > 0 ? onTapLeft : null,
              tooltip: strings.text('a11y.previousMode'),
              style: IconButton.styleFrom(
                backgroundColor: selectedIndex > 0
                    ? AppColors.surface.withOpacity(0.78)
                    : Colors.transparent,
                side: BorderSide(
                  color: selectedIndex > 0
                      ? Colors.white.withOpacity(0.12)
                      : Colors.transparent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              color: AppColors.textLight,
              disabledColor: AppColors.textMuted.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: ModePreviewCard(
                key: ValueKey(selectedIndex),
                presentation: presentation,
                title: modeName,
                subtitle: _bestScoreText(context, selectedIndex),
                onTap: onTapCenter,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed:
                  selectedIndex < modeCount - 1 ? onTapRight : null,
              tooltip: strings.text('a11y.nextMode'),
              style: IconButton.styleFrom(
                backgroundColor: selectedIndex < modeCount - 1
                    ? AppColors.surface.withOpacity(0.78)
                    : Colors.transparent,
                side: BorderSide(
                  color: selectedIndex < modeCount - 1
                      ? Colors.white.withOpacity(0.12)
                      : Colors.transparent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              color: AppColors.textLight,
              disabledColor: AppColors.textMuted.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Play Button (unchanged) ────────────────────────────────────────────────────

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.label, required this.onTap});
  final String label;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
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
        label: widget.label,
        semanticLabel: widget.label,
        onPressed: widget.onTap,
        color: AppColors.accent,
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
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
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
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  boxShadow: isActive
                      ? [
                          ...PaperShadows.buttonEdge(AppColors.accentDeep, dy: 4),
                          ...PaperShadows.accentGlow(AppColors.accent),
                        ]
                      : PaperShadows.buttonEdge(
                          AppColors.paperShadowWarm,
                          dy: 4,
                        ),
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
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: isActive
                      ? AppColors.accent
                      : AppColors.textSubtle,
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
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
                      ? PaperShadows.accentGlow(AppColors.accent, blur: 4)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

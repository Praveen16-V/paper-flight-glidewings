import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/settings_model.dart';
import '../../providers/settings_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/onboarding_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../enums/game_enums.dart';
import 'paper_button.dart';
import 'paper_card.dart';
import 'paper_icons.dart';

/// Presents the reusable four-page guide.
///
/// On first run, leaving through either Skip or Done records completion so the
/// dialog never traps a returning player. The guide remains available from the
/// menu and pause screen at any time.
Future<void> showHowToPlayDialog(
  BuildContext context, {
  bool firstRun = false,
  int initialPage = 0,
  String surface = 'manual',
}) async {
  unawaited(
    AnalyticsService.instance.logOnboarding(
      action: 'opened',
      surface: surface,
      page: initialPage,
    ),
  );

  final completed = await showDialog<bool>(
    context: context,
    barrierDismissible: !firstRun,
    useSafeArea: true,
    builder: (_) => _HowToPlayDialog(
      firstRun: firstRun,
      initialPage: initialPage,
    ),
  );

  if (firstRun && completed != null) {
    await OnboardingService.instance.completeTutorial();
    unawaited(
      AnalyticsService.instance.logOnboarding(
        action: completed ? 'completed' : 'skipped',
        surface: surface,
      ),
    );
  } else {
    unawaited(
      AnalyticsService.instance.logOnboarding(
        action: 'closed',
        surface: surface,
      ),
    );
  }
}

class _HowToPlayDialog extends ConsumerStatefulWidget {
  const _HowToPlayDialog({
    required this.firstRun,
    required this.initialPage,
  });

  final bool firstRun;
  final int initialPage;

  @override
  ConsumerState<_HowToPlayDialog> createState() => _HowToPlayDialogState();
}

class _HowToPlayDialogState extends ConsumerState<_HowToPlayDialog> {
  static const int _pageCount = 4;
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _pageCount - 1).toInt();
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final settings = ref.watch(settingsProvider);

    return WillPopScope(
      onWillPop: () async => !widget.firstRun,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
          child: PaperCard(
            color: AppColors.paperBright,
            elevation: 2,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _GuideHeader(
                  page: _page,
                  pageCount: _pageCount,
                  firstRun: widget.firstRun,
                  onClose: () => Navigator.of(context).pop(true),
                ),
                const Divider(height: 1, color: AppColors.paperDivider),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (page) {
                      setState(() => _page = page);
                      unawaited(
                        AnalyticsService.instance.logOnboarding(
                          action: 'page_viewed',
                          surface: widget.firstRun ? 'first_run' : 'manual',
                          page: page,
                        ),
                      );
                    },
                    children: [
                      _ControlsPage(settings: settings),
                      const _ScoringPage(),
                      const _PowerUpsPage(),
                      const _FlightLoopPage(),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.paperDivider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      if (widget.firstRun && _page == 0)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(64, 48),
                            foregroundColor: AppColors.paperInkSoft,
                          ),
                          child: Text(strings.text('guide.skip')),
                        )
                      else
                        TextButton.icon(
                          onPressed: _page > 0 ? _previous : null,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(88, 48),
                            foregroundColor: AppColors.paperInkSoft,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(strings.text('guide.back')),
                        ),
                      const Spacer(),
                      Semantics(
                        label: strings.text('guide.page', {
                          'current': _page + 1,
                          'total': _pageCount,
                        }),
                        child: ExcludeSemantics(
                          child: Row(
                            children: List.generate(
                              _pageCount,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: index == _page ? 20 : 7,
                                height: 7,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: index == _page
                                      ? AppColors.accent
                                      : AppColors.paperInkSoft.withOpacity(0.24),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      PaperButton(
                        label: strings.text(
                          _page == _pageCount - 1
                              ? 'guide.done'
                              : 'guide.next',
                        ),
                        compact: true,
                        onPressed: _page == _pageCount - 1
                            ? () => Navigator.of(context).pop(true)
                            : _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _previous() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({
    required this.page,
    required this.pageCount,
    required this.firstRun,
    required this.onClose,
  });

  final int page;
  final int pageCount;
  final bool firstRun;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(
              child: PaperIcon(
                PaperIconData.glider,
                size: 24,
                color: AppColors.accentDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text('guide.title'),
                  style: AppTypography.title.copyWith(
                    color: AppColors.paperInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  strings.text('guide.page', {
                    'current': page + 1,
                    'total': pageCount,
                  }),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (!firstRun)
            IconButton(
              onPressed: onClose,
              tooltip: strings.text('guide.close'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.close_rounded),
              color: AppColors.paperInk,
            )
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

class _GuidePageShell extends StatelessWidget {
  const _GuidePageShell({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.children,
    required this.accent,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
          ),
          child: Icon(icon, color: accent, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          strings.text(titleKey),
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: AppColors.paperInk),
        ),
        const SizedBox(height: 8),
        Text(
          strings.text(bodyKey),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.paperInkSoft,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        ...children,
      ],
    );
  }
}

class _ControlsPage extends StatelessWidget {
  const _ControlsPage({required this.settings});

  final SettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final steerBodyKey = switch (settings.controlScheme) {
      ControlScheme.tilt => 'guide.steerTilt',
      ControlScheme.joystick => 'guide.steerJoystick',
      ControlScheme.touchZones => 'guide.steerZones',
    };
    final steerIcon = switch (settings.controlScheme) {
      ControlScheme.tilt => Icons.screen_rotation_rounded,
      ControlScheme.joystick => Icons.gamepad_rounded,
      ControlScheme.touchZones => Icons.touch_app_rounded,
    };

    return _GuidePageShell(
      icon: Icons.pan_tool_alt_rounded,
      titleKey: 'guide.controlsTitle',
      bodyKey: 'guide.controlsBody',
      accent: AppColors.accentDeep,
      children: [
        const _GuideRow(
          icon: Icons.vertical_align_top_rounded,
          titleKey: 'guide.holdTitle',
          bodyKey: 'guide.holdBody',
          color: AppColors.accentDeep,
        ),
        const SizedBox(height: 12),
        _GuideRow(
          icon: steerIcon,
          titleKey: 'guide.steerTitle',
          bodyKey: steerBodyKey,
          color: AppColors.gemBlueDeep,
        ),
        const SizedBox(height: 12),
        const _GuideRow(
          icon: Icons.rocket_launch_rounded,
          titleKey: 'guide.boostTitle',
          bodyKey: 'guide.boostBody',
          color: AppColors.danger,
        ),
      ],
    );
  }
}

class _ScoringPage extends StatelessWidget {
  const _ScoringPage();

  @override
  Widget build(BuildContext context) {
    return const _GuidePageShell(
      icon: Icons.insights_rounded,
      titleKey: 'guide.scoringTitle',
      bodyKey: 'guide.scoringBody',
      accent: AppColors.accentDeep,
      children: [
        _GuideRow(
          icon: Icons.route_rounded,
          titleKey: 'guide.distanceTitle',
          bodyKey: 'guide.distanceBody',
          color: AppColors.gemBlueDeep,
        ),
        SizedBox(height: 12),
        _GuideRow(
          icon: Icons.link_rounded,
          titleKey: 'guide.comboTitle',
          bodyKey: 'guide.comboBody',
          color: AppColors.coinGoldDeep,
        ),
        SizedBox(height: 12),
        _GuideRow(
          icon: Icons.compress_rounded,
          titleKey: 'guide.nearMissTitle',
          bodyKey: 'guide.nearMissBody',
          color: AppColors.danger,
        ),
        SizedBox(height: 12),
        _GuideRow(
          icon: Icons.air_rounded,
          titleKey: 'guide.cleanTitle',
          bodyKey: 'guide.cleanBody',
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _PowerUpsPage extends StatelessWidget {
  const _PowerUpsPage();

  @override
  Widget build(BuildContext context) {
    return _GuidePageShell(
      icon: Icons.auto_awesome_rounded,
      titleKey: 'guide.powerTitle',
      bodyKey: 'guide.powerBody',
      accent: AppColors.gemBlueDeep,
      children: const [
        _PowerUpWrap(),
      ],
    );
  }
}

class _PowerUpWrap extends StatelessWidget {
  const _PowerUpWrap();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _PowerUpTile(
          icon: Icons.shield_rounded,
          titleKey: 'guide.shield',
          bodyKey: 'guide.shieldBody',
          color: AppColors.guideShield,
        ),
        _PowerUpTile(
          icon: Icons.my_location_rounded,
          titleKey: 'guide.magnet',
          bodyKey: 'guide.magnetBody',
          color: AppColors.guideMagnet,
        ),
        _PowerUpTile(
          icon: Icons.visibility_off_rounded,
          titleKey: 'guide.ghost',
          bodyKey: 'guide.ghostBody',
          color: AppColors.guideGhost,
        ),
        _PowerUpTile(
          icon: Icons.timer_rounded,
          titleKey: 'guide.slowMo',
          bodyKey: 'guide.slowMoBody',
          color: AppColors.guideSlowMo,
        ),
        _PowerUpTile(
          icon: Icons.monetization_on_rounded,
          titleKey: 'guide.coinRush',
          bodyKey: 'guide.coinRushBody',
          color: AppColors.guideCoinRush,
        ),
      ],
    );
  }
}

class _PowerUpTile extends StatelessWidget {
  const _PowerUpTile({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.color,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 195),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text(titleKey),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.paperInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.text(bodyKey),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.paperInkSoft,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlightLoopPage extends StatelessWidget {
  const _FlightLoopPage();

  @override
  Widget build(BuildContext context) {
    return const _GuidePageShell(
      icon: Icons.alt_route_rounded,
      titleKey: 'guide.loopTitle',
      bodyKey: 'guide.loopBody',
      accent: AppColors.success,
      children: [
        _LoopRow(
          icon: PaperIconData.glider,
          titleKey: 'mode.classic',
          bodyKey: 'guide.classicLoop',
          color: AppColors.accentDeep,
        ),
        SizedBox(height: 12),
        _LoopRow(
          icon: PaperIconData.leaf,
          titleKey: 'mode.zen',
          bodyKey: 'guide.zenLoop',
          color: AppColors.success,
        ),
        SizedBox(height: 12),
        _LoopRow(
          icon: PaperIconData.calendar,
          titleKey: 'mode.daily',
          bodyKey: 'guide.dailyLoop',
          color: AppColors.gemBlueDeep,
        ),
        SizedBox(height: 12),
        _LoopRow(
          icon: PaperIconData.bullseye,
          titleKey: 'mode.trial',
          bodyKey: 'guide.trialLoop',
          color: AppColors.danger,
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.color,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paperWarm.withOpacity(0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.paperInk.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text(titleKey),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.paperInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  strings.text(bodyKey),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopRow extends StatelessWidget {
  const _LoopRow({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.color,
  });

  final PaperIconData icon;
  final String titleKey;
  final String bodyKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperIcon(icon, size: 28, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text(titleKey),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.paperInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  strings.text(bodyKey),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

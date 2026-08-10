import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../enums/game_enums.dart';
import 'paper_button.dart';
import 'paper_card.dart';
import 'paper_icons.dart';

/// One-time, mode-specific pre-flight card shown before a run is consumed.
///
/// In particular, the Daily warning appears before [PaperFlightGame.startRun]
/// marks the attempt as used. That makes the irreversible rule visible at the
/// moment it matters instead of explaining it after the player has committed.
class ModeIntroOverlay extends StatelessWidget {
  const ModeIntroOverlay({
    super.key,
    required this.mode,
    required this.controlScheme,
    required this.onStart,
    required this.onOpenGuide,
    this.detail,
  });

  final GameMode mode;
  final ControlScheme controlScheme;
  final VoidCallback onStart;
  final VoidCallback onOpenGuide;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final presentation = _presentationFor(mode);
    final controlKey = switch (controlScheme) {
      ControlScheme.tilt => 'intro.controlTilt',
      ControlScheme.joystick => 'intro.controlJoystick',
      ControlScheme.touchZones => 'intro.controlZones',
    };

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.76),
        child: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Semantics(
                  container: true,
                  namesRoute: true,
                  child: PaperCard(
                    color: presentation.paperColor,
                    elevation: 2,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    borderColor: presentation.accent.withOpacity(0.5),
                    borderWidth: 1.6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.text('intro.eyebrow'),
                          textAlign: TextAlign.center,
                          style: AppTypography.overline.copyWith(
                            color: presentation.accent,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 68,
                          height: 68,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: presentation.accent.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: presentation.accent.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: PaperIcon(
                            presentation.icon,
                            color: presentation.accent,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.text(presentation.titleKey),
                          textAlign: TextAlign.center,
                          style: AppTypography.headline.copyWith(
                            color: AppColors.paperInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          strings.text(presentation.bodyKey),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.paperInkSoft,
                            height: 1.45,
                          ),
                        ),
                        if (detail != null && detail!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            detail!,
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.paperInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _RulePill(
                          icon: presentation.ruleIcon,
                          label: strings.text(presentation.ruleKey),
                          color: presentation.accent,
                        ),
                        const SizedBox(height: 10),
                        _RulePill(
                          icon: _controlIcon(controlScheme),
                          label: strings.text('intro.control', {
                            'control': strings.text(controlKey),
                          }),
                          color: AppColors.paperInkSoft,
                        ),
                        const SizedBox(height: 20),
                        PaperButton(
                          label: strings.text('intro.start'),
                          expand: true,
                          color: presentation.accent,
                          textColor: presentation.buttonTextColor,
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: onStart,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: onOpenGuide,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.paperInkSoft,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          icon: const Icon(Icons.help_outline_rounded, size: 19),
                          label: Text(strings.text('intro.fullGuide')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _controlIcon(ControlScheme scheme) {
    return switch (scheme) {
      ControlScheme.tilt => Icons.screen_rotation_rounded,
      ControlScheme.joystick => Icons.gamepad_rounded,
      ControlScheme.touchZones => Icons.touch_app_rounded,
    };
  }

  _ModeIntroPresentation _presentationFor(GameMode value) {
    return switch (value) {
      GameMode.classic => const _ModeIntroPresentation(
          titleKey: 'mode.classic',
          bodyKey: 'intro.classicBody',
          ruleKey: 'intro.classicRule',
          icon: PaperIconData.glider,
          ruleIcon: Icons.savings_outlined,
          accent: AppColors.accentDeep,
          paperColor: AppColors.paperGold,
          buttonTextColor: AppColors.paperInk,
        ),
      GameMode.zen => const _ModeIntroPresentation(
          titleKey: 'mode.zen',
          bodyKey: 'intro.zenBody',
          ruleKey: 'intro.zenRule',
          icon: PaperIconData.leaf,
          ruleIcon: Icons.spa_outlined,
          accent: Color(0xFF27834F),
          paperColor: AppColors.paperGreen,
          buttonTextColor: Colors.white,
        ),
      GameMode.daily => const _ModeIntroPresentation(
          titleKey: 'mode.daily',
          bodyKey: 'intro.dailyBody',
          ruleKey: 'intro.dailyRule',
          icon: PaperIconData.calendar,
          ruleIcon: Icons.looks_one_outlined,
          accent: Color(0xFF18759E),
          paperColor: AppColors.paperBlue,
          buttonTextColor: Colors.white,
        ),
      GameMode.trial => const _ModeIntroPresentation(
          titleKey: 'mode.trial',
          bodyKey: 'intro.trialBody',
          ruleKey: 'intro.trialRule',
          icon: PaperIconData.bullseye,
          ruleIcon: Icons.warning_amber_rounded,
          accent: Color(0xFFB73838),
          paperColor: AppColors.paperRose,
          buttonTextColor: Colors.white,
        ),
    };
  }
}

class _RulePill extends StatelessWidget {
  const _RulePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.paperInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeIntroPresentation {
  const _ModeIntroPresentation({
    required this.titleKey,
    required this.bodyKey,
    required this.ruleKey,
    required this.icon,
    required this.ruleIcon,
    required this.accent,
    required this.paperColor,
    required this.buttonTextColor,
  });

  final String titleKey;
  final String bodyKey;
  final String ruleKey;
  final PaperIconData icon;
  final IconData ruleIcon;
  final Color accent;
  final Color paperColor;
  final Color buttonTextColor;
}

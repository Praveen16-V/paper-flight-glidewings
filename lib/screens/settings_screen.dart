import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/how_to_play_dialog.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/screen_backdrop.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScreenBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _TitleBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Controls group ───────────────────────────────────
                    _SectionHeader(title: 'Controls'),
                    const SizedBox(height: 12),
                    // Grouped controls card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.paperInk.withOpacity(0.12), offset: const Offset(0, 4), blurRadius: 1),
                          BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 2), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: _SegmentedRow<ControlScheme>(
                              label: 'Steering',
                              options: const [ControlScheme.tilt, ControlScheme.joystick, ControlScheme.touchZones],
                              labels: const ['Tilt', 'Joystick', 'Zones'],
                              selected: settings.controlScheme,
                              onChanged: (v) => notifier.setControlScheme(v),
                            ),
                          ),
                          Divider(height: 1, color: AppColors.paperInkSoft.withOpacity(0.15)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: _SliderRow(
                              label: settings.controlScheme == ControlScheme.joystick
                                  ? 'Steering Sensitivity'
                                  : 'Tilt Sensitivity',
                              value: settings.tiltSensitivity,
                              min: 0.3,
                              max: 2.0,
                              divisions: 17,
                              enabled: settings.controlScheme == ControlScheme.tilt ||
                                  settings.controlScheme == ControlScheme.joystick,
                              onChanged: (v) => notifier.setTiltSensitivity(v),
                              valueLabel: settings.tiltSensitivity.toStringAsFixed(1),
                            ),
                          ),
                          if (settings.controlScheme == ControlScheme.joystick ||
                              settings.controlScheme == ControlScheme.touchZones) ...[
                            Divider(height: 1, color: AppColors.paperInkSoft.withOpacity(0.15)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: _SwitchRow(
                                label: settings.controlScheme == ControlScheme.joystick
                                    ? 'Show joystick on screen'
                                    : 'Show control zones on screen',
                                value: settings.showOnScreenControls,
                                onChanged: (v) => notifier.setShowOnScreenControls(v),
                              ),
                            ),
                          ],
                          Divider(height: 1, color: AppColors.paperInkSoft.withOpacity(0.15)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: _SwitchRow(
                              label: 'Flick to use power-up',
                              value: settings.flickToUsePowerUp,
                              onChanged: (v) => notifier.setFlickToUsePowerUp(v),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ControlPreview(scheme: settings.controlScheme),
                    const SizedBox(height: 8),
                    if (settings.controlScheme == ControlScheme.joystick)
                      _InfoBox(
                        icon: Icons.gamepad,
                        text: 'Touch anywhere — a virtual stick appears under your thumb. Slide to steer, hold to climb. Flick up or tap BOOST for the snap.',
                      ),
                    const SizedBox(height: 32),

                    // ── Audio group ──────────────────────────────────────
                    _SectionHeader(title: 'Audio'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.paperInk.withOpacity(0.12), offset: const Offset(0, 4), blurRadius: 1),
                          BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 2), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: _SwitchRow(
                              label: 'Sound Effects',
                              value: settings.sfxEnabled,
                              onChanged: (v) => notifier.setSfxEnabled(v),
                            ),
                          ),
                          Divider(height: 1, color: AppColors.paperInkSoft.withOpacity(0.15)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: _SliderRow(
                              label: 'SFX Volume',
                              value: settings.sfxVolume,
                              min: 0,
                              max: 1,
                              divisions: 10,
                              enabled: settings.sfxEnabled,
                              onChanged: (v) => notifier.setSfxVolume(v),
                              valueLabel: '${(settings.sfxVolume * 100).toInt()}%',
                            ),
                          ),
                          Divider(height: 1, color: AppColors.paperInkSoft.withOpacity(0.15)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: _SwitchRow(
                              label: 'Music',
                              value: settings.musicEnabled,
                              onChanged: (v) => notifier.setMusicEnabled(v),
                            ),
                          ),
                          Divider(height: 1, color: AppColors.paperInkSoft.withOpacity(0.15)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: _SliderRow(
                              label: 'Music Volume',
                              value: settings.musicVolume,
                              min: 0,
                              max: 1,
                              divisions: 10,
                              enabled: settings.musicEnabled,
                              onChanged: (v) => notifier.setMusicVolume(v),
                              valueLabel: '${(settings.musicVolume * 100).toInt()}%',
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Haptics group ────────────────────────────────────
                    _SectionHeader(title: 'Haptics'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.paperInk.withOpacity(0.12), offset: const Offset(0, 4), blurRadius: 1),
                          BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 2), blurRadius: 6),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _SwitchRow(
                          label: 'Vibration',
                          value: settings.hapticEnabled,
                          onChanged: (v) => notifier.setHapticEnabled(v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Calibration tip ──────────────────────────────────
                    _CalibrationNote(scheme: settings.controlScheme),
                    const SizedBox(height: 24),

                    // ── Reset to Defaults ────────────────────────────────
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.restart_alt_rounded,
                            color: AppColors.danger, size: 16),
                        label: Text(
                          'Reset All Settings to Defaults',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.danger,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.danger,
                          ),
                        ),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.paper,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            title: Text('Reset Settings?',
                                style: AppTypography.title
                                    .copyWith(color: AppColors.paperInk)),
                            content: Text(
                              'This will restore all controls, audio and haptic settings to their defaults.',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.paperInkSoft),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: AppColors.paperInkSoft)),
                              ),
                              TextButton(
                                onPressed: () {
                                  notifier.resetToDefaults();
                                  Navigator.pop(ctx);
                                },
                                child: Text('Reset',
                                    style: TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Interactive Control Preview ─────────────────────────────────────────────

class _ControlPreview extends StatefulWidget {
  const _ControlPreview({required this.scheme});
  final ControlScheme scheme;
  @override
  State<_ControlPreview> createState() => _ControlPreviewState();
}

class _ControlPreviewState extends State<_ControlPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void didUpdateWidget(covariant _ControlPreview old) {
    super.didUpdateWidget(old);
    if (old.scheme != widget.scheme) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paperBright,
      elevation: 1.1,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.16), borderRadius: BorderRadius.circular(6)),
                  child: Text('PREVIEW', style: AppTypography.overline.copyWith(color: AppColors.accentDeep, fontSize: 8, letterSpacing: 1.0))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _labelFor(widget.scheme),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Icon(_iconFor(widget.scheme), size: 14, color: AppColors.paperInkSoft.withOpacity(0.55)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value; // 0..1
              final sinVal = math.sin(t * 2 * math.pi); // -1..1
              final cosVal = math.cos(t * 2 * math.pi);
              return SizedBox(
                height: 110,
                child: Row(
                  children: [
                    // miniature phone silhouette
                    Expanded(
                      child: Center(
                        child: _PhoneSilhouette(scheme: widget.scheme, steer: sinVal, tiltPhase: cosVal),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // legend / arrow
                    SizedBox(
                      width: 96,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreviewLegendDot(color: AppColors.accent, label: _actionLabel(widget.scheme)),
                          const SizedBox(height: 8),
                          _PreviewLegendDot(color: AppColors.paperInkSoft.withOpacity(0.45), label: 'Altitude: hold'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.backgroundDeep.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                            child: Text(_hintFor(widget.scheme),
                                style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 9, height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _labelFor(ControlScheme s) {
    switch (s) {
      case ControlScheme.tilt:
        return 'Tilt phone to steer';
      case ControlScheme.joystick:
        return 'Drag joystick to steer';
      case ControlScheme.touchZones:
        return 'Tap left / right to steer';
    }
  }

  IconData _iconFor(ControlScheme s) {
    switch (s) {
      case ControlScheme.tilt:
        return Icons.screen_rotation_rounded;
      case ControlScheme.joystick:
        return Icons.gamepad_rounded;
      case ControlScheme.touchZones:
        return Icons.touch_app_rounded;
    }
  }

  String _actionLabel(ControlScheme s) {
    switch (s) {
      case ControlScheme.tilt:
        return 'Steer: tilt';
      case ControlScheme.joystick:
        return 'Steer: drag';
      case ControlScheme.touchZones:
        return 'Steer: tap zones';
    }
  }

  String _hintFor(ControlScheme s) {
    switch (s) {
      case ControlScheme.tilt:
        return 'Phone roll → plane banks';
      case ControlScheme.joystick:
        return 'Knob deflects → banks';
      case ControlScheme.touchZones:
        return 'Half-screen zones';
    }
  }
}

class _PreviewLegendDot extends StatelessWidget {
  const _PreviewLegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 10, height: 1.3),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

class _PhoneSilhouette extends StatelessWidget {
  const _PhoneSilhouette({required this.scheme, required this.steer, required this.tiltPhase});
  final ControlScheme scheme;
  final double steer; // -1..1
  final double tiltPhase;

  @override
  Widget build(BuildContext context) {
    // phone rotates slightly for tilt mode
    final phoneAngle = scheme == ControlScheme.tilt ? steer * 0.22 : 0.0; // radians
    final planeOffset = steer * 26; // plane horizontal drift inside phone
    final joystickOffset = steer * 14;
    final leftActive = steer < -0.18;
    final rightActive = steer > 0.18;

    return Transform.rotate(
      angle: phoneAngle,
      child: Container(
        width: 78,
        height: 108,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // sky gradient inside phone
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6EC6FF), Color(0xFFF6EEDC)]),
                ),
              ),
              // faint grid
              Positioned.fill(child: CustomPaint(painter: _PhoneGridPainter())),
              // touch zones overlay for Zones mode
              if (scheme == ControlScheme.touchZones)
                Row(children: [
                  Expanded(
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          color: leftActive ? AppColors.accent.withOpacity(0.22) : Colors.white.withOpacity(0.04),
                          child: Center(
                              child: AnimatedOpacity(
                                  opacity: leftActive ? 1 : 0.35,
                                  duration: const Duration(milliseconds: 120),
                                  child: Icon(Icons.arrow_back_rounded, size: 14, color: leftActive ? AppColors.accentDeep : Colors.white.withOpacity(0.55)))))),
                  Container(width: 1, color: Colors.white.withOpacity(0.18)),
                  Expanded(
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          color: rightActive ? AppColors.accent.withOpacity(0.22) : Colors.white.withOpacity(0.04),
                          child: Center(
                              child: AnimatedOpacity(
                                  opacity: rightActive ? 1 : 0.35,
                                  duration: const Duration(milliseconds: 120),
                                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: rightActive ? AppColors.accentDeep : Colors.white.withOpacity(0.55)))))),
                ]),
              // joystick base + knob for joystick mode
              if (scheme == ControlScheme.joystick)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.22)))),
                          // knob
                          Transform.translate(
                            offset: Offset(joystickOffset, 0),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.4),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 4)]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // plane
              Positioned(
                left: 0,
                right: 0,
                top: 28,
                child: Transform.translate(
                  offset: Offset(planeOffset, math.sin(tiltPhase * 3) * 1.5),
                  child: Transform.rotate(
                    angle: steer * 0.38,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.paperBright,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppColors.paperInk.withOpacity(0.14)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 4)],
                        ),
                        child: CustomPaint(painter: _MiniPlanePainter(color: AppColors.accent)),
                      ),
                    ),
                  ),
                ),
              ),
              // hold indicator at top when steering centered? always show
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.22), borderRadius: BorderRadius.circular(6)),
                    child: Text('HOLD = CLIMB',
                        style: AppTypography.overline.copyWith(color: Colors.white.withOpacity(0.88), fontSize: 6, letterSpacing: 0.8)),
                  ),
                ),
              ),
              // notch
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(height: 6, decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.18)..strokeWidth = 0.5;
    // horizontal lines
    for (double y = size.height * 0.22; y < size.height; y += 14) {
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), p);
    }
    // vertical center line faint
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height),
        Paint()..color = Colors.white.withOpacity(0.10)..strokeWidth = 0.7);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniPlanePainter extends CustomPainter {
  _MiniPlanePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w, h / 2)
      ..lineTo(0, 0)
      ..lineTo(w * 0.28, h / 2)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(Offset(w * 0.08, h / 2), Offset(w * 0.62, h / 2), Paint()..color = Colors.white.withOpacity(0.45)..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── rest of original widgets unchanged ─────────────────────────────────────

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: AppTypography.headline,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: AppColors.textLight,
            ),
            tooltip: 'How to play',
            onPressed: () => showHowToPlayDialog(
              context,
              surface: 'settings',
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationNote extends StatelessWidget {
  const _CalibrationNote({required this.scheme});
  final ControlScheme scheme;
  String get _text {
    switch (scheme) {
      case ControlScheme.tilt:
        return 'Hold your phone in your normal playing position, then start a run — tilt auto-calibrates to your posture each run.';
      case ControlScheme.joystick:
        return 'The joystick is floating — it appears wherever you touch, so one thumb is all you need. Great for tablets and one-handed play. Your BOOST charges recharge over distance.';
      case ControlScheme.touchZones:
        return 'Zones: tap left or right half of screen to steer. Hold anywhere to climb. Use flick-up or BOOST for emergency snap.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded,
              color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text,
              style: AppTypography.caption.copyWith(
                color: AppColors.textLight.withOpacity(0.85),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.caption.copyWith(height: 1.4));
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paperBlue,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(icon, color: AppColors.accentDeep, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTypography.caption.copyWith(color: AppColors.paperInk, height: 1.4))),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title.toUpperCase(), style: AppTypography.overline);
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(
        child: Text(label,
            style: AppTypography.bodyLarge.copyWith(
                color: AppColors.paperInk, fontSize: 15)),
      ),
      Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accent,
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accent.withOpacity(0.4)
                  : AppColors.paperInkSoft.withOpacity(0.3))),
    ]);
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged, required this.valueLabel, this.enabled = true});
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String valueLabel;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(label,
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.paperInk, fontSize: 15)),
          ),
          Text(valueLabel,
              style: AppTypography.statSmall
                  .copyWith(color: AppColors.accentDeep, fontSize: 14)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.paperInkSoft.withOpacity(0.3),
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withOpacity(0.2)),
          child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null),
        ),
      ]),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({required this.label, required this.options, required this.labels, required this.selected, required this.onChanged});
  final String label;
  final List<T> options;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    // Brighter sheet than the grouped card it sits in, so the nested
    // "sheet-on-sheet" layering reads cleanly with its folded bottom edge.
    return PaperCard(
      color: AppColors.paperBright,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTypography.bodyLarge.copyWith(color: AppColors.paperInk, fontSize: 15)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(options.length, (i) {
            final isSelected = options[i] == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(options[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.paperWarm,
                    borderRadius: BorderRadius.horizontal(left: i == 0 ? const Radius.circular(10) : Radius.zero, right: i == options.length - 1 ? const Radius.circular(10) : Radius.zero),
                    border: Border.all(color: AppColors.paperInkSoft.withOpacity(0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i],
                      style: AppTypography.bodyMedium.copyWith(
                          color: isSelected ? Colors.white : AppColors.paperInkSoft,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

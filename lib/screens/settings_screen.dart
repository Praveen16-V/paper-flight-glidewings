import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/paper_card.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceAlt, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TitleBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionHeader(title: 'Controls'),
                    const SizedBox(height: 12),
                    _SegmentedRow<ControlScheme>(
                      label: 'Steering',
                      options: const [
                        ControlScheme.tilt,
                        ControlScheme.joystick,
                        ControlScheme.touchZones
                      ],
                      labels: const ['Tilt', 'Joystick', 'Zones'],
                      selected: settings.controlScheme,
                      onChanged: (v) => notifier.setControlScheme(v),
                    ),
                    const SizedBox(height: 16),
                    if (settings.controlScheme == ControlScheme.joystick)
                      _InfoBox(
                        icon: Icons.gamepad,
                        text:
                            'Touch anywhere — a virtual stick appears under your thumb. Slide to steer, hold to climb. Flick up or tap BOOST for the snap.',
                      ),
                    if (settings.controlScheme == ControlScheme.joystick)
                      const SizedBox(height: 16),
                    _SliderRow(
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
                    if (settings.controlScheme == ControlScheme.joystick ||
                        settings.controlScheme == ControlScheme.touchZones) ...[
                      const SizedBox(height: 20),
                      _SwitchRow(
                        label: settings.controlScheme == ControlScheme.joystick
                            ? 'Show joystick on screen'
                            : 'Show control zones on screen',
                        value: settings.showOnScreenControls,
                        onChanged: (v) =>
                            notifier.setShowOnScreenControls(v),
                      ),
                      const SizedBox(height: 6),
                      _Hint(
                        settings.controlScheme == ControlScheme.joystick
                            ? 'Hide the floating stick for a cleaner view — touching anywhere still steers.'
                            : 'Hide the zone guides for a cleaner view — tapping left or right half still steers.',
                      ),
                    ],
                    const SizedBox(height: 20),
                    _SwitchRow(
                      label: 'Flick to use power-up',
                      value: settings.flickToUsePowerUp,
                      onChanged: (v) => notifier.setFlickToUsePowerUp(v),
                    ),
                    const SizedBox(height: 6),
                    const _Hint(
                      'Flick up or double-tap fires your plane\'s power-up — Dart: BOOST · Glider: Magnet · Stunt Fold: Ghost. The BOOST button always works.',
                    ),
                    const SizedBox(height: 32),

                    _SectionHeader(title: 'Audio'),
                    const SizedBox(height: 12),
                    _SwitchRow(
                      label: 'Sound Effects',
                      value: settings.sfxEnabled,
                      onChanged: (v) => notifier.setSfxEnabled(v),
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'SFX Volume',
                      value: settings.sfxVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      enabled: settings.sfxEnabled,
                      onChanged: (v) => notifier.setSfxVolume(v),
                      valueLabel: '${(settings.sfxVolume * 100).toInt()}%',
                    ),
                    const SizedBox(height: 16),
                    _SwitchRow(
                      label: 'Music',
                      value: settings.musicEnabled,
                      onChanged: (v) => notifier.setMusicEnabled(v),
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'Music Volume',
                      value: settings.musicVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      enabled: settings.musicEnabled,
                      onChanged: (v) => notifier.setMusicVolume(v),
                      valueLabel: '${(settings.musicVolume * 100).toInt()}%',
                    ),
                    const SizedBox(height: 32),

                    _SectionHeader(title: 'Haptics'),
                    const SizedBox(height: 12),
                    _SwitchRow(
                      label: 'Vibration',
                      value: settings.hapticEnabled,
                      onChanged: (v) => notifier.setHapticEnabled(v),
                    ),
                    const SizedBox(height: 40),

                    _CalibrationNote(scheme: settings.controlScheme),
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

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text('Settings',
                textAlign: TextAlign.center, style: AppTypography.headline),
          ),
          const SizedBox(width: 48),
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
    return PaperCard(
      color: AppColors.paperWarm,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.paperInkSoft, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text,
              style: AppTypography.caption
                  .copyWith(color: AppColors.paperInkSoft, height: 1.5),
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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(height: 1.4),
    );
  }
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
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentDeep, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTypography.caption.copyWith(
                    color: AppColors.paperInk, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: AppTypography.overline);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paper,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.paperInk, fontSize: 15)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.accent.withOpacity(0.4)
                    : AppColors.paperInkSoft.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.valueLabel,
    this.enabled = true,
  });
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
      child: PaperCard(
        color: AppColors.paper,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.paperInk, fontSize: 15)),
                ),
                Text(valueLabel,
                    style: AppTypography.statSmall.copyWith(
                        color: AppColors.accentDeep, fontSize: 14)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.paperInkSoft.withOpacity(0.3),
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withOpacity(0.2),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.options,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final List<T> options;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.paperInk, fontSize: 15)),
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
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.paperWarm,
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0
                            ? const Radius.circular(10)
                            : Radius.zero,
                        right: i == options.length - 1
                            ? const Radius.circular(10)
                            : Radius.zero,
                      ),
                      border: Border.all(
                          color: AppColors.paperInkSoft.withOpacity(0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.paperInk
                            : AppColors.paperInkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

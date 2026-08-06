import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/enums/game_enums.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Controls ────────────────────────────────────────────────────
          _SectionHeader(title: 'Controls'),
          const SizedBox(height: 12),

          _SegmentedRow<ControlScheme>(
            label: 'Steering',
            options: const [
              ControlScheme.tilt,
              ControlScheme.drag,
              ControlScheme.touchZones
            ],
            labels: const ['Tilt', 'Drag', 'Zones'],
            selected: settings.controlScheme,
            onChanged: (v) => notifier.setControlScheme(v),
          ),
          const SizedBox(height: 16),
          // Explain drag mode.
          if (settings.controlScheme == ControlScheme.drag)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: AppColors.accent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Drag: slide finger left/right to steer. Hold anywhere to climb. Flick up or tap BOOST for emergency snap.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (settings.controlScheme == ControlScheme.drag) const SizedBox(height: 16),
          _SliderRow(
            label: settings.controlScheme == ControlScheme.drag
                ? 'Drag / Steering Sensitivity'
                : 'Tilt Sensitivity',
            value: settings.tiltSensitivity,
            min: 0.3,
            max: 2.0,
            divisions: 17,
            enabled: settings.controlScheme == ControlScheme.tilt ||
                settings.controlScheme == ControlScheme.drag,
            onChanged: (v) => notifier.setTiltSensitivity(v),
            valueLabel: settings.tiltSensitivity.toStringAsFixed(1),
          ),
          const SizedBox(height: 32),

          // ── Audio ────────────────────────────────────────────────────────
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

          // ── Haptics ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Haptics'),
          const SizedBox(height: 12),
          _SwitchRow(
            label: 'Vibration',
            value: settings.hapticEnabled,
            onChanged: (v) => notifier.setHapticEnabled(v),
          ),

          const SizedBox(height: 40),

          // ── Calibration tip ───────────────────────────────────────────────
          if (settings.controlScheme == ControlScheme.tilt)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hold your phone in your normal playing position, then start a run — tilt auto-calibrates to your posture each run.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (settings.controlScheme == ControlScheme.drag)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Drag uses one finger only — no tilt needed. Great for tablets and one-handed play. Your BOOST charges recharge over distance.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (settings.controlScheme == ControlScheme.touchZones)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zones: tap left or right half of screen to steer. Hold anywhere to climb. Use flick-up or BOOST for emergency snap.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
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

// ── Shared setting row widgets ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
    );
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accent,
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accent.withOpacity(0.4)
                  : AppColors.divider),
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 16)),
              Text(valueLabel,
                  style: const TextStyle(
                      color: AppColors.accent, fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.divider,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
        Row(
          children: List.generate(options.length, (i) {
            final isSelected = options[i] == selected;
            return GestureDetector(
              onTap: () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0
                        ? const Radius.circular(8)
                        : Radius.zero,
                    right: i == options.length - 1
                        ? const Radius.circular(8)
                        : Radius.zero,
                  ),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

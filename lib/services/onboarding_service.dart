import 'package:hive_flutter/hive_flutter.dart';

import '../core/enums/game_enums.dart';

/// Persists tutorial and one-time contextual-tip state independently from the
/// player save schema.
///
/// These keys live in the existing settings box so adding a tutorial page or a
/// mode tip never requires a SaveData TypeAdapter migration. The in-memory
/// fallback keeps widget tests and recovery-mode starts safe when Hive is not
/// available.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const String _tutorialKey = 'onboarding.tutorial.v1.complete';
  static const String _modePrefix = 'onboarding.mode_tip.v1.';

  bool _memoryTutorialComplete = false;
  final Set<GameMode> _memorySeenModes = <GameMode>{};

  Box<dynamic>? get _settingsBox {
    try {
      if (!Hive.isBoxOpen('settings')) return null;
      return Hive.box<dynamic>('settings');
    } catch (_) {
      return null;
    }
  }

  bool get hasCompletedTutorial {
    final box = _settingsBox;
    if (box == null) return _memoryTutorialComplete;
    return box.get(_tutorialKey, defaultValue: false) as bool? ?? false;
  }

  bool hasSeenModeTip(GameMode mode) {
    final box = _settingsBox;
    if (box == null) return _memorySeenModes.contains(mode);
    return box.get('$_modePrefix${mode.name}', defaultValue: false) as bool? ??
        false;
  }

  Future<void> completeTutorial() async {
    _memoryTutorialComplete = true;
    try {
      await _settingsBox?.put(_tutorialKey, true);
    } catch (_) {}
  }

  Future<void> markModeTipSeen(GameMode mode) async {
    _memorySeenModes.add(mode);
    try {
      await _settingsBox?.put('$_modePrefix${mode.name}', true);
    } catch (_) {}
  }

  /// Used by the Settings replay action and tests. The next visit to each mode
  /// will show its contextual card again.
  Future<void> resetGuidance() async {
    _memoryTutorialComplete = false;
    _memorySeenModes.clear();
    final box = _settingsBox;
    if (box == null) return;
    try {
      await box.delete(_tutorialKey);
      for (final mode in GameMode.values) {
        await box.delete('$_modePrefix${mode.name}');
      }
    } catch (_) {}
  }
}

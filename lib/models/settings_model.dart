import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';

/// Mutable settings — persisted to Hive 'settings' box.
class SettingsModel {
  SettingsModel({
    this.tiltSensitivity = GameConfig.defaultTiltSensitivity,
    this.controlScheme = ControlScheme.tilt,
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.sfxVolume = 0.8,
    this.musicVolume = 0.5,
    this.hapticEnabled = true,
    this.showOnScreenControls = true,
    this.flickToUsePowerUp = true,
  });

  double tiltSensitivity; // 0.3 – 2.0
  ControlScheme controlScheme;
  bool sfxEnabled;
  bool musicEnabled;
  double sfxVolume;
  double musicVolume;
  bool hapticEnabled;

  /// Whether the on-screen control visuals (floating joystick for the
  /// [ControlScheme.joystick] scheme, touch-zone guides for the
  /// [ControlScheme.touchZones] scheme) are drawn on top of the game.
  /// Input always works regardless — this only affects visibility.
  bool showOnScreenControls;

  /// Whether the flick-up / double-tap gesture fires the equipped plane's
  /// signature power-up (Dart: BOOST burst, Glider: Magnet, Stunt Fold: Ghost).
  /// When off, the gesture does nothing.
  bool flickToUsePowerUp;

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      tiltSensitivity: (map['tiltSensitivity'] as num?)?.toDouble() ??
          GameConfig.defaultTiltSensitivity,
      controlScheme: ControlScheme.values[
          (map['controlScheme'] as int?) ?? ControlScheme.tilt.index],
      sfxEnabled: map['sfxEnabled'] as bool? ?? true,
      musicEnabled: map['musicEnabled'] as bool? ?? true,
      sfxVolume: (map['sfxVolume'] as num?)?.toDouble() ?? 0.8,
      musicVolume: (map['musicVolume'] as num?)?.toDouble() ?? 0.5,
      hapticEnabled: map['hapticEnabled'] as bool? ?? true,
      showOnScreenControls: map['showOnScreenControls'] as bool? ?? true,
      flickToUsePowerUp: map['flickToUsePowerUp'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'tiltSensitivity': tiltSensitivity,
        'controlScheme': controlScheme.index,
        'sfxEnabled': sfxEnabled,
        'musicEnabled': musicEnabled,
        'sfxVolume': sfxVolume,
        'musicVolume': musicVolume,
        'hapticEnabled': hapticEnabled,
        'showOnScreenControls': showOnScreenControls,
        'flickToUsePowerUp': flickToUsePowerUp,
      };
}

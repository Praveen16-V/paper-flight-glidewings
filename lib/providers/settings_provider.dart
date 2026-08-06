import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../core/enums/game_enums.dart';
import '../services/persistence_service.dart';

class SettingsNotifier extends Notifier<SettingsModel> {
  @override
  SettingsModel build() {
    return PersistenceService.instance.loadSettings();
  }

  Future<void> setTiltSensitivity(double value) async {
    state.tiltSensitivity = value.clamp(0.3, 2.0);
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setControlScheme(ControlScheme scheme) async {
    state.controlScheme = scheme;
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setSfxEnabled(bool enabled) async {
    state.sfxEnabled = enabled;
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setMusicEnabled(bool enabled) async {
    state.musicEnabled = enabled;
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setSfxVolume(double value) async {
    state.sfxVolume = value.clamp(0.0, 1.0);
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setMusicVolume(double value) async {
    state.musicVolume = value.clamp(0.0, 1.0);
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    state.hapticEnabled = enabled;
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setShowOnScreenControls(bool enabled) async {
    state.showOnScreenControls = enabled;
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }

  Future<void> setFlickToUsePowerUp(bool enabled) async {
    state.flickToUsePowerUp = enabled;
    state = SettingsModel.fromMap(state.toMap());
    await PersistenceService.instance.writeSettings(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsModel>(
  SettingsNotifier.new,
);

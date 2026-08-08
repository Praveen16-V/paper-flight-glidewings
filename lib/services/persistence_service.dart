import 'package:hive_flutter/hive_flutter.dart';

import '../models/save_data.dart';
import '../models/settings_model.dart';

/// Single access point for all persistent storage.
/// Wrap all Hive reads/writes here — nothing else should touch boxes directly.
class PersistenceService {
  PersistenceService._();
  static final PersistenceService instance = PersistenceService._();

  static const String _saveKey = 'player_save';

  Box<SaveData> get _saveBox => Hive.box<SaveData>('save_data');
  Box get _settingsBox => Hive.box('settings');

  // ── Save Data ──────────────────────────────────────────────────────────────

  SaveData loadSave() {
    final save = _saveBox.get(_saveKey);
    return save?.clone() ?? SaveData.fresh();
  }

  Future<void> writeSave(SaveData data) async {
    await _saveBox.put(_saveKey, data);
  }

  /// Convenience: load → mutate via [updater] → write.
  Future<SaveData> updateSave(SaveData Function(SaveData) updater) async {
    final current = loadSave();
    final updated = updater(current);
    await writeSave(updated);
    return updated.clone();
  }

  Future<void> resetSave() async {
    await writeSave(SaveData.fresh());
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  SettingsModel loadSettings() {
    final raw = _settingsBox.toMap().cast<String, dynamic>();
    return SettingsModel.fromMap(raw);
  }

  Future<void> writeSettings(SettingsModel settings) async {
    await _settingsBox.putAll(settings.toMap());
  }
}

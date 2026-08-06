// GENERATED CODE - DO NOT MODIFY BY HAND
// Hand-maintained Hive TypeAdapter for SaveData (MVP).
// Run `flutter pub run build_runner build` to regenerate if you add fields.

part of 'save_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaveDataAdapter extends TypeAdapter<SaveData> {
  @override
  final int typeId = 0;

  @override
  SaveData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaveData(
      coins: (fields[0] as num?)?.toInt() ?? 0,
      gems: (fields[1] as num?)?.toInt() ?? 0,
      highScore: (fields[2] as num?)?.toInt() ?? 0,
      highDistanceMeters: (fields[3] as num?)?.toDouble() ?? 0,
      totalRuns: (fields[4] as num?)?.toInt() ?? 0,
      totalCoinsCollected: (fields[5] as num?)?.toInt() ?? 0,
      totalNearMisses: (fields[6] as num?)?.toInt() ?? 0,
      unlockedPlaneIndices: (fields[7] as List?)?.cast<int>() ?? [0],
      equippedPlaneIndex: (fields[8] as num?)?.toInt() ?? 0,
      adsRemoved: fields[9] as bool? ?? false,
      runsSinceLastInterstitial: (fields[10] as num?)?.toInt() ?? 0,
      isFirstSession: fields[11] as bool? ?? true,
      lastDailyLoginMs: (fields[12] as num?)?.toInt() ?? 0,
      dailyLoginStreak: (fields[13] as num?)?.toInt() ?? 0,
      pendingStartShield: fields[14] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, SaveData obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.coins)
      ..writeByte(1)
      ..write(obj.gems)
      ..writeByte(2)
      ..write(obj.highScore)
      ..writeByte(3)
      ..write(obj.highDistanceMeters)
      ..writeByte(4)
      ..write(obj.totalRuns)
      ..writeByte(5)
      ..write(obj.totalCoinsCollected)
      ..writeByte(6)
      ..write(obj.totalNearMisses)
      ..writeByte(7)
      ..write(obj.unlockedPlaneIndices)
      ..writeByte(8)
      ..write(obj.equippedPlaneIndex)
      ..writeByte(9)
      ..write(obj.adsRemoved)
      ..writeByte(10)
      ..write(obj.runsSinceLastInterstitial)
      ..writeByte(11)
      ..write(obj.isFirstSession)
      ..writeByte(12)
      ..write(obj.lastDailyLoginMs)
      ..writeByte(13)
      ..write(obj.dailyLoginStreak)
      ..writeByte(14)
      ..write(obj.pendingStartShield);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

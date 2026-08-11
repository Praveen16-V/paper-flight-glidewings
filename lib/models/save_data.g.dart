// GENERATED CODE - DO NOT MODIFY BY HAND
// Run `flutter pub run build_runner build` to regenerate.

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
      unlockedSkinIndices: (fields[14] as List?)?.cast<int>() ?? [0],
      equippedSkinIndex: (fields[15] as num?)?.toInt() ?? 0,
      lastDailyChallengeMs: (fields[16] as num?)?.toInt() ?? 0,
      dailyChallengeIds: (fields[17] as List?)?.cast<int>() ?? [],
      dailyChallengeProgress: (fields[18] as List?)?.cast<int>() ?? [],
      dailyChallengeCompleted: (fields[19] as List?)?.cast<bool>() ?? [],
      dailyChallengeClaimed: (fields[20] as List?)?.cast<bool>() ?? [],
      lastWeeklyChallengeMs: (fields[21] as num?)?.toInt() ?? 0,
      weeklyChallengeIds: (fields[22] as List?)?.cast<int>() ?? [],
      weeklyChallengeProgress: (fields[23] as List?)?.cast<int>() ?? [],
      weeklyChallengeCompleted: (fields[24] as List?)?.cast<bool>() ?? [],
      weeklyChallengeClaimed: (fields[25] as List?)?.cast<bool>() ?? [],
      dailyLastSeed: (fields[26] as num?)?.toInt() ?? 0,
      dailyAttemptUsed: fields[27] as bool? ?? false,
      trialStars: (fields[28] as List?)?.cast<int>() ?? [],
      zenBestDistanceMeters: (fields[29] as num?)?.toDouble() ?? 0,
      planeUpgradeLevels: (fields[30] as List?)?.cast<int>() ?? List.filled(16, 1),
      customSkinPrimaryHex: (fields[31] as num?)?.toInt() ?? 0xFF4FC3F7,
      customSkinAccentHex: (fields[32] as num?)?.toInt() ?? 0xFFFFD54F,
      customSkinStamp: (fields[33] as num?)?.toInt() ?? 0,
      skinWearLevels: ((fields[34] as List?) ?? const <dynamic>[])
          .map<double>((value) => (value as num).toDouble())
          .toList(),
      customSkinPatternBase64: fields[35] as String? ?? '',
      customSkinPatternName: fields[36] as String? ?? '',
      powerUpUpgradeLevels: (fields[37] as List?)?.cast<int>() ??
          List.filled(16, 1),
    );
  }

  @override
  void write(BinaryWriter writer, SaveData obj) {
    writer
      ..writeByte(38)
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
      ..write(obj.unlockedSkinIndices)
      ..writeByte(15)
      ..write(obj.equippedSkinIndex)
      ..writeByte(16)
      ..write(obj.lastDailyChallengeMs)
      ..writeByte(17)
      ..write(obj.dailyChallengeIds)
      ..writeByte(18)
      ..write(obj.dailyChallengeProgress)
      ..writeByte(19)
      ..write(obj.dailyChallengeCompleted)
      ..writeByte(20)
      ..write(obj.dailyChallengeClaimed)
      ..writeByte(21)
      ..write(obj.lastWeeklyChallengeMs)
      ..writeByte(22)
      ..write(obj.weeklyChallengeIds)
      ..writeByte(23)
      ..write(obj.weeklyChallengeProgress)
      ..writeByte(24)
      ..write(obj.weeklyChallengeCompleted)
      ..writeByte(25)
      ..write(obj.weeklyChallengeClaimed)
      ..writeByte(26)
      ..write(obj.dailyLastSeed)
      ..writeByte(27)
      ..write(obj.dailyAttemptUsed)
      ..writeByte(28)
      ..write(obj.trialStars)
      ..writeByte(29)
      ..write(obj.zenBestDistanceMeters)
      ..writeByte(30)
      ..write(obj.planeUpgradeLevels)
      ..writeByte(31)
      ..write(obj.customSkinPrimaryHex)
      ..writeByte(32)
      ..write(obj.customSkinAccentHex)
      ..writeByte(33)
      ..write(obj.customSkinStamp)
      ..writeByte(34)
      ..write(obj.skinWearLevels)
      ..writeByte(35)
      ..write(obj.customSkinPatternBase64)
      ..writeByte(36)
      ..write(obj.customSkinPatternName)
      ..writeByte(37)
      ..write(obj.powerUpUpgradeLevels);
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

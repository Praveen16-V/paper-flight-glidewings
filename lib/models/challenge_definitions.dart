import '../core/enums/game_enums.dart';

/// Immutable definition of a challenge objective.
class ChallengeDefinition {
  const ChallengeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.rewardCoins,
    required this.rewardGems,
    required this.period,
    this.biome,
    this.icon,
  });

  final int id;
  final String title;
  final String description;
  final ChallengeType type;
  final int target;
  final int rewardCoins;
  final int rewardGems;
  final ChallengePeriod period;
  final Biome? biome;
  final String? icon;

  /// Whether this challenge must be completed in a single run
  /// (vs cumulative across the period).
  bool get isSingleRun {
    switch (type) {
      case ChallengeType.rideThermalsSingleRun:
      case ChallengeType.coinComboInBiome:
      case ChallengeType.skyscraperGapsNoPowerUp:
      case ChallengeType.collectCoinsSingleRun:
      case ChallengeType.nearMissesSingleRun:
      case ChallengeType.travelDistanceSingleRun:
        return true;
      case ChallengeType.collectCoinsTotal:
      case ChallengeType.nearMissesTotal:
      case ChallengeType.travelDistanceTotal:
      case ChallengeType.surviveRuns:
      case ChallengeType.usePowerUps:
      case ChallengeType.buildingGapsTotal:
      case ChallengeType.rideThermalsTotal:
        return false;
    }
  }
}

/// Full pool of challenge definitions.
/// Daily picks 3 from dailyPool, Weekly picks 3 from weeklyPool.
abstract class ChallengePool {
  // ── Daily pool (12 varied) ───────────────────────────────────────────────
  static const List<ChallengeDefinition> daily = [
    ChallengeDefinition(
      id: 0,
      title: 'Ride 3 thermals in a single run',
      description: 'Catch 3 thermal updrafts before crashing',
      type: ChallengeType.rideThermalsSingleRun,
      target: 3,
      rewardCoins: 120,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '🌬️',
    ),
    ChallengeDefinition(
      id: 1,
      title: 'Achieve an 8× coin combo in the Storm biome',
      description: 'Build an 8× streak while flying through Storm',
      type: ChallengeType.coinComboInBiome,
      target: 8,
      rewardCoins: 150,
      rewardGems: 1,
      period: ChallengePeriod.daily,
      biome: Biome.storm,
      icon: '⛈️',
    ),
    ChallengeDefinition(
      id: 2,
      title: 'Pass through 10 skyscraper gaps without using a power-up',
      description: 'Thread 10 building gaps in one clean run',
      type: ChallengeType.skyscraperGapsNoPowerUp,
      target: 10,
      rewardCoins: 150,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '🏙️',
    ),
    ChallengeDefinition(
      id: 3,
      title: 'Collect 50 coins in one run',
      description: 'Grab 50 coins before your plane goes down',
      type: ChallengeType.collectCoinsSingleRun,
      target: 50,
      rewardCoins: 100,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '🪙',
    ),
    ChallengeDefinition(
      id: 4,
      title: 'Score 5 near misses in one run',
      description: 'Graze 5 obstacles — closer is better',
      type: ChallengeType.nearMissesSingleRun,
      target: 5,
      rewardCoins: 80,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '💨',
    ),
    ChallengeDefinition(
      id: 5,
      title: 'Fly 1,500 m in a single run',
      description: 'Soar at least 1,500 meters in one flight',
      type: ChallengeType.travelDistanceSingleRun,
      target: 1500,
      rewardCoins: 100,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '📏',
    ),
    ChallengeDefinition(
      id: 6,
      title: 'Collect 100 coins today',
      description: 'Cumulatively collect 100 coins',
      type: ChallengeType.collectCoinsTotal,
      target: 100,
      rewardCoins: 120,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '💰',
    ),
    ChallengeDefinition(
      id: 7,
      title: 'Use 3 power-ups',
      description: 'Activate any 3 power-ups',
      type: ChallengeType.usePowerUps,
      target: 3,
      rewardCoins: 75,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '⚡',
    ),
    ChallengeDefinition(
      id: 8,
      title: 'Play 3 runs',
      description: 'Complete 3 flights today',
      type: ChallengeType.surviveRuns,
      target: 3,
      rewardCoins: 50,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '✈️',
    ),
    ChallengeDefinition(
      id: 9,
      title: 'Ride 5 thermals total',
      description: 'Catch 5 thermals across all runs today',
      type: ChallengeType.rideThermalsTotal,
      target: 5,
      rewardCoins: 90,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '🔥',
    ),
    ChallengeDefinition(
      id: 10,
      title: 'Pass 15 building gaps',
      description: 'Thread 15 skyscraper gaps in any runs',
      type: ChallengeType.buildingGapsTotal,
      target: 15,
      rewardCoins: 100,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '🏢',
    ),
    ChallengeDefinition(
      id: 11,
      title: 'Earn 10 near misses today',
      description: 'Cumulatively earn 10 near misses',
      type: ChallengeType.nearMissesTotal,
      target: 10,
      rewardCoins: 90,
      rewardGems: 0,
      period: ChallengePeriod.daily,
      icon: '🎯',
    ),
  ];

  // ── Weekly pool (8 harder, gem rewards) ─────────────────────────────────
  static const List<ChallengeDefinition> weekly = [
    ChallengeDefinition(
      id: 100,
      title: 'Collect 500 coins',
      description: 'Cumulatively collect 500 coins this week',
      type: ChallengeType.collectCoinsTotal,
      target: 500,
      rewardCoins: 300,
      rewardGems: 5,
      period: ChallengePeriod.weekly,
      icon: '💎',
    ),
    ChallengeDefinition(
      id: 101,
      title: 'Ride 20 thermals',
      description: 'Catch 20 thermal updrafts this week',
      type: ChallengeType.rideThermalsTotal,
      target: 20,
      rewardCoins: 250,
      rewardGems: 3,
      period: ChallengePeriod.weekly,
      icon: '🌪️',
    ),
    ChallengeDefinition(
      id: 102,
      title: 'Achieve 12× coin combo',
      description: 'Build a 12× streak in any biome',
      type: ChallengeType.coinComboInBiome,
      target: 12,
      rewardCoins: 200,
      rewardGems: 4,
      period: ChallengePeriod.weekly,
      // no biome lock = any biome
      icon: '🔥',
    ),
    ChallengeDefinition(
      id: 103,
      title: 'Fly 10,000 m total',
      description: 'Cumulatively fly 10,000 meters',
      type: ChallengeType.travelDistanceTotal,
      target: 10000,
      rewardCoins: 400,
      rewardGems: 5,
      period: ChallengePeriod.weekly,
      icon: '🗺️',
    ),
    ChallengeDefinition(
      id: 104,
      title: 'Pass 50 skyscraper gaps',
      description: 'Thread 50 building gaps',
      type: ChallengeType.buildingGapsTotal,
      target: 50,
      rewardCoins: 250,
      rewardGems: 3,
      period: ChallengePeriod.weekly,
      icon: '🏙️',
    ),
    ChallengeDefinition(
      id: 105,
      title: 'Score 30 near misses',
      description: 'Earn 30 near misses this week',
      type: ChallengeType.nearMissesTotal,
      target: 30,
      rewardCoins: 200,
      rewardGems: 3,
      period: ChallengePeriod.weekly,
      icon: '⚡',
    ),
    ChallengeDefinition(
      id: 106,
      title: 'Use 15 power-ups',
      description: 'Activate 15 power-ups',
      type: ChallengeType.usePowerUps,
      target: 15,
      rewardCoins: 150,
      rewardGems: 2,
      period: ChallengePeriod.weekly,
      icon: '🎁',
    ),
    ChallengeDefinition(
      id: 107,
      title: 'Play 10 runs',
      description: 'Complete 10 flights this week',
      type: ChallengeType.surviveRuns,
      target: 10,
      rewardCoins: 200,
      rewardGems: 2,
      period: ChallengePeriod.weekly,
      icon: '✈️',
    ),
  ];

  static ChallengeDefinition? byId(int id) {
    for (final d in daily) {
      if (d.id == id) return d;
    }
    for (final d in weekly) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<ChallengeDefinition> forIds(List<int> ids) =>
      ids.map(byId).whereType<ChallengeDefinition>().toList();
}

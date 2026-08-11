import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../paper_flight_game.dart';

/// Tracks which biome the player is currently in based on distance traveled.
/// Notifies game systems when a biome transition occurs.
///
/// Task 8: biome progression is mode-aware —
///  - Classic / Daily: the standard backyard → city → storm → mountain →
///    night → atmosphere journey.
///  - Zen Flight: only calm biomes (Backyard Morning, then Mountain Pass).
///  - Precision Trials: pinned to the trial's biome for the whole course.
class BiomeManager extends Component {
  BiomeManager({required this.game});

  final PaperFlightGame game;

  Biome _currentBiome = Biome.city; // MVP starts in city
  Biome get currentBiome => _currentBiome;

  final List<void Function(Biome from, Biome to)> _listeners = [];

  void addTransitionListener(void Function(Biome from, Biome to) cb) {
    _listeners.add(cb);
  }

  @override
  void update(double dt) {
    final dist = game.distanceMeters;
    final newBiome = switch (game.mode) {
      GameMode.trial => _currentBiome, // pinned to the trial biome
      GameMode.zen => _zenBiomeForDistance(dist),
      GameMode.classic || GameMode.daily => _biomeForDistance(dist),
    };
    if (newBiome != _currentBiome) {
      final old = _currentBiome;
      _currentBiome = newBiome;
      game.ref.read(gameSessionProvider.notifier).updateBiome(newBiome);
      for (final cb in _listeners) {
        cb(old, newBiome);
      }
    }
  }

  /// Resets biome state for a new run in [mode].
  void reset(GameMode mode) {
    switch (mode) {
      case GameMode.trial:
        _currentBiome = game.trial?.biome ?? Biome.city;
      case GameMode.zen:
        _currentBiome = Biome.backyard;
      case GameMode.classic:
      case GameMode.daily:
        _currentBiome = Biome.city;
    }
  }

  static Biome _biomeForDistance(double meters) {
    if (meters < GameConfig.biomeBackyardEnd) return Biome.backyard;
    if (meters < GameConfig.biomeCityEnd) return Biome.city;
    if (meters < GameConfig.biomeStormEnd) return Biome.storm;
    if (meters < GameConfig.biomeMountainEnd) return Biome.mountain;
    if (meters < GameConfig.biomeNightEnd) return Biome.night;
    if (meters < GameConfig.biomeOceanEnd) return Biome.ocean;
    return Biome.atmosphere;
  }

  /// Zen only visits the calm biomes: Backyard Morning first, then a gentle
  /// endless Mountain Pass. Never storm, never night, never the atmosphere.
  static Biome _zenBiomeForDistance(double meters) {
    if (meters < GameConfig.zenBiomeMountainAt) return Biome.backyard;
    return Biome.mountain;
  }

  /// Returns the spawn weight for a given obstacle type in the current biome.
  /// Weight 0 = never spawns.
  double obstacleWeight(ObstacleType type) {
    switch (_currentBiome) {
      case Biome.backyard:
        return const {
          ObstacleType.treeBranch: 1.2,
          ObstacleType.clothesline: 1.1,
          ObstacleType.kite: 1.0,
          ObstacleType.bird: 0.8,
          ObstacleType.windsock: 0.6,
          ObstacleType.trafficPlane: 0.4,
          ObstacleType.powerLine: 0.3,
          ObstacleType.hotAirBalloon: 0.2,
          ObstacleType.building: 0.0,
          ObstacleType.drone: 0.0,
          ObstacleType.windTurbine: 0.0,
          ObstacleType.stormCloud: 0.0,
          ObstacleType.fireworks: 0.0,
          ObstacleType.weatherBalloon: 0.0,
          ObstacleType.flockMigration: 0.32,
        }[type] ?? 0.0;
      case Biome.city:
        return const {
          ObstacleType.building: 1.2,
          ObstacleType.powerLine: 1.1,
          ObstacleType.drone: 0.9,
          ObstacleType.trafficPlane: 0.8,
          ObstacleType.bird: 0.7,
          ObstacleType.treeBranch: 0.3,
          ObstacleType.windsock: 0.3,
          ObstacleType.kite: 0.2,
          ObstacleType.hotAirBalloon: 0.1,
          ObstacleType.clothesline: 0.1,
          ObstacleType.windTurbine: 0.0,
          ObstacleType.stormCloud: 0.0,
          ObstacleType.fireworks: 0.0,
          ObstacleType.weatherBalloon: 0.0,
          ObstacleType.flockMigration: 0.18,
        }[type] ?? 0.0;
      case Biome.storm:
        return const {
          ObstacleType.stormCloud: 1.4,
          ObstacleType.powerLine: 1.2,
          ObstacleType.windTurbine: 0.8,
          ObstacleType.building: 0.7,
          ObstacleType.drone: 0.6,
          ObstacleType.windsock: 0.5,
          ObstacleType.trafficPlane: 0.4,
          ObstacleType.treeBranch: 0.3,
          ObstacleType.bird: 0.2,
          ObstacleType.kite: 0.1,
          ObstacleType.hotAirBalloon: 0.0,
          ObstacleType.clothesline: 0.0,
          ObstacleType.fireworks: 0.0,
          ObstacleType.weatherBalloon: 0.0,
          ObstacleType.lightningStrike: 1.25,
          ObstacleType.meteorShower: 0.0,
          ObstacleType.tornado: 0.70,
        }[type] ?? 0.0;
      case Biome.mountain:
        return const {
          ObstacleType.windTurbine: 1.3,
          ObstacleType.bird: 1.2,
          ObstacleType.hotAirBalloon: 0.9,
          ObstacleType.treeBranch: 0.8,
          ObstacleType.windsock: 0.7,
          ObstacleType.kite: 0.5,
          ObstacleType.stormCloud: 0.3,
          ObstacleType.powerLine: 0.2,
          ObstacleType.trafficPlane: 0.2,
          ObstacleType.weatherBalloon: 0.2,
          ObstacleType.building: 0.0,
          ObstacleType.drone: 0.1,
          ObstacleType.clothesline: 0.0,
          ObstacleType.fireworks: 0.0,
          ObstacleType.flockMigration: 0.78,
        }[type] ?? 0.0;
      case Biome.night:
        return const {
          ObstacleType.drone: 1.4,
          ObstacleType.fireworks: 1.2,
          ObstacleType.building: 1.0,
          ObstacleType.hotAirBalloon: 0.9,
          ObstacleType.trafficPlane: 0.8,
          ObstacleType.powerLine: 0.7,
          ObstacleType.kite: 0.5,
          ObstacleType.bird: 0.4,
          ObstacleType.stormCloud: 0.3,
          ObstacleType.treeBranch: 0.2,
          ObstacleType.windTurbine: 0.2,
          ObstacleType.windsock: 0.2,
          ObstacleType.weatherBalloon: 0.1,
          ObstacleType.clothesline: 0.0,
          ObstacleType.lightningStrike: 0.25,
          ObstacleType.meteorShower: 0.0,
          ObstacleType.tornado: 0.15,
          ObstacleType.paperDragon: 0.10,
        }[type] ?? 0.0;
      case Biome.ocean:
        return const {
          ObstacleType.whaleBreach: 1.45,
          ObstacleType.weatherBalloon: 0.35,
          ObstacleType.kite: 0.30,
          ObstacleType.bird: 0.28,
          ObstacleType.trafficPlane: 0.18,
          ObstacleType.tornado: 0.10,
          ObstacleType.flockMigration: 0.08,
          ObstacleType.paperDragon: 0.24,
        }[type] ?? 0.0;
      case Biome.atmosphere:
        return const {
          ObstacleType.weatherBalloon: 1.4,
          ObstacleType.hotAirBalloon: 1.3,
          ObstacleType.drone: 1.2,
          ObstacleType.windTurbine: 1.0,
          ObstacleType.stormCloud: 0.9,
          ObstacleType.fireworks: 0.8,
          ObstacleType.trafficPlane: 0.7,
          ObstacleType.kite: 0.6,
          ObstacleType.bird: 0.5,
          ObstacleType.powerLine: 0.2,
          ObstacleType.windsock: 0.1,
          ObstacleType.building: 0.1,
          ObstacleType.treeBranch: 0.0,
          ObstacleType.clothesline: 0.0,
          ObstacleType.lightningStrike: 0.35,
          ObstacleType.meteorShower: 1.45,
          ObstacleType.tornado: 0.50,
          ObstacleType.paperDragon: 0.40,
        }[type] ?? 0.0;
    }
  }

  /// Returns the authored-combination weight for this biome. Normal obstacle
  /// weights still drive all other spawns; a nonzero result only authorizes a
  /// curated pair once the spawner's cadence and safety gates approve it.
  double obstacleCombinationWeight(ObstacleCombination combination) {
    switch (_currentBiome) {
      case Biome.backyard:
        return 0.0;
      case Biome.city:
        return combination == ObstacleCombination.cityTrafficStack ? .72 : 0.0;
      case Biome.storm:
        return combination == ObstacleCombination.stormCrossfire ? .90 : 0.0;
      case Biome.mountain:
        return switch (combination) {
          ObstacleCombination.rotorRun => .88,
          ObstacleCombination.kiteRelay => .34,
          _ => 0.0,
        };
      case Biome.night:
        return switch (combination) {
          ObstacleCombination.cityTrafficStack => .44,
          ObstacleCombination.stormCrossfire => .30,
          _ => 0.0,
        };
      case Biome.ocean:
        return combination == ObstacleCombination.kiteRelay ? .56 : 0.0;
      case Biome.atmosphere:
        return switch (combination) {
          ObstacleCombination.stormCrossfire => .62,
          ObstacleCombination.cityTrafficStack => .32,
          ObstacleCombination.rotorRun => .24,
          _ => 0.0,
        };
    }
  }
}

import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../paper_flight_game.dart';

/// Tracks which biome the player is currently in based on distance traveled.
/// Notifies game systems when a biome transition occurs.
///
/// MVP starts in Backyard Morning (tutorial-safe) then progresses through
/// City Rooftops and beyond (GDD §4).
class BiomeManager extends Component {
  BiomeManager({required this.game});

  final PaperFlightGame game;

  Biome _currentBiome = Biome.backyard;
  Biome get currentBiome => _currentBiome;

  final List<void Function(Biome from, Biome to)> _listeners = [];

  void addTransitionListener(void Function(Biome from, Biome to) cb) {
    _listeners.add(cb);
  }

  @override
  void update(double dt) {
    if (game.phase != GamePhase.playing) return;

    final dist = game.distanceMeters;
    final newBiome = _biomeForDistance(dist);
    if (newBiome != _currentBiome) {
      final old = _currentBiome;
      _currentBiome = newBiome;
      game.ref.read(gameSessionProvider.notifier).updateBiome(newBiome);
      for (final cb in List.of(_listeners)) {
        cb(old, newBiome);
      }
    }
  }

  void reset() {
    _currentBiome = Biome.backyard;
    game.ref.read(gameSessionProvider.notifier).updateBiome(Biome.backyard);
  }

  void restore(Biome biome) {
    _currentBiome = biome;
    game.ref.read(gameSessionProvider.notifier).updateBiome(biome);
  }

  static Biome _biomeForDistance(double meters) {
    if (meters < GameConfig.biomeBackyardEnd) return Biome.backyard;
    if (meters < GameConfig.biomeCityEnd) return Biome.city;
    if (meters < GameConfig.biomeStormEnd) return Biome.storm;
    if (meters < GameConfig.biomeMountainEnd) return Biome.mountain;
    if (meters < GameConfig.biomeNightEnd) return Biome.night;
    return Biome.atmosphere;
  }

  /// Returns the spawn weight for a given obstacle type in the current biome.
  /// Weight 0 = never spawns.
  double obstacleWeight(ObstacleType type) {
    switch (_currentBiome) {
      case Biome.backyard:
        // Tutorial-safe: mostly branches + occasional birds.
        return const {
          ObstacleType.treeBranch: 1.0,
          ObstacleType.bird: 0.4,
          ObstacleType.powerLine: 0.15,
          ObstacleType.building: 0.0,
          ObstacleType.drone: 0.0,
        }[type]!;
      case Biome.city:
        return const {
          ObstacleType.powerLine: 1.2,
          ObstacleType.building: 1.0,
          ObstacleType.bird: 0.8,
          ObstacleType.treeBranch: 0.4,
          ObstacleType.drone: 0.2,
        }[type]!;
      case Biome.storm:
        return const {
          ObstacleType.powerLine: 1.5,
          ObstacleType.bird: 0.3,
          ObstacleType.building: 0.8,
          ObstacleType.treeBranch: 0.5,
          ObstacleType.drone: 0.4,
        }[type]!;
      case Biome.mountain:
        return const {
          ObstacleType.treeBranch: 1.5,
          ObstacleType.bird: 1.2,
          ObstacleType.building: 0.0,
          ObstacleType.powerLine: 0.2,
          ObstacleType.drone: 0.1,
        }[type]!;
      case Biome.night:
        return const {
          ObstacleType.drone: 1.5,
          ObstacleType.powerLine: 0.8,
          ObstacleType.building: 0.6,
          ObstacleType.bird: 0.3,
          ObstacleType.treeBranch: 0.3,
        }[type]!;
      case Biome.atmosphere:
        return const {
          ObstacleType.drone: 1.2,
          ObstacleType.bird: 1.0,
          ObstacleType.powerLine: 0.5,
          ObstacleType.building: 0.3,
          ObstacleType.treeBranch: 0.2,
        }[type]!;
    }
  }

  /// Wind intensity multiplier by biome (storm = stronger gusts).
  double get windIntensityMultiplier {
    switch (_currentBiome) {
      case Biome.backyard:
        return 0.4;
      case Biome.city:
        return 0.8;
      case Biome.storm:
        return 1.5;
      case Biome.mountain:
        return 1.1;
      case Biome.night:
        return 0.9;
      case Biome.atmosphere:
        return 1.3;
    }
  }
}

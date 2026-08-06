import 'package:flame/components.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../providers/game_session_provider.dart';
import '../paper_flight_game.dart';

/// Tracks which biome the player is currently in based on distance traveled.
/// Notifies game systems when a biome transition occurs.
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
    final newBiome = _biomeForDistance(dist);
    if (newBiome != _currentBiome) {
      final old = _currentBiome;
      _currentBiome = newBiome;
      game.ref.read(gameSessionProvider.notifier).updateBiome(newBiome);
      for (final cb in _listeners) {
        cb(old, newBiome);
      }
    }
  }

  void reset() {
    _currentBiome = Biome.city;
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
        return const {
          ObstacleType.treeBranch: 1.0,
          ObstacleType.bird: 0.5,
          ObstacleType.powerLine: 0.3,
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
          ObstacleType.drone: 1.0,
          ObstacleType.bird: 0.8,
          ObstacleType.powerLine: 0.4,
          ObstacleType.building: 0.2,
          ObstacleType.treeBranch: 0.1,
        }[type]!;
    }
  }
}

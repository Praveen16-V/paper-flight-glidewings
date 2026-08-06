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
          ObstacleType.treeBranch: 1.2,
          ObstacleType.kite: 1.0,
          ObstacleType.bird: 0.7,
          ObstacleType.powerLine: 0.3,
          ObstacleType.hotAirBalloon: 0.2,
          ObstacleType.building: 0.0,
          ObstacleType.drone: 0.0,
          ObstacleType.windTurbine: 0.0,
          ObstacleType.stormCloud: 0.0,
        }[type] ?? 0.0;
      case Biome.city:
        return const {
          ObstacleType.building: 1.2,
          ObstacleType.powerLine: 1.1,
          ObstacleType.drone: 0.9,
          ObstacleType.bird: 0.7,
          ObstacleType.treeBranch: 0.3,
          ObstacleType.kite: 0.2,
          ObstacleType.hotAirBalloon: 0.1,
          ObstacleType.windTurbine: 0.0,
          ObstacleType.stormCloud: 0.0,
        }[type] ?? 0.0;
      case Biome.storm:
        return const {
          ObstacleType.stormCloud: 1.4,
          ObstacleType.powerLine: 1.2,
          ObstacleType.windTurbine: 0.8,
          ObstacleType.building: 0.7,
          ObstacleType.drone: 0.6,
          ObstacleType.treeBranch: 0.3,
          ObstacleType.bird: 0.2,
          ObstacleType.kite: 0.1,
          ObstacleType.hotAirBalloon: 0.0,
        }[type] ?? 0.0;
      case Biome.mountain:
        return const {
          ObstacleType.windTurbine: 1.3,
          ObstacleType.bird: 1.2,
          ObstacleType.hotAirBalloon: 0.9,
          ObstacleType.treeBranch: 0.8,
          ObstacleType.kite: 0.5,
          ObstacleType.stormCloud: 0.3,
          ObstacleType.powerLine: 0.2,
          ObstacleType.building: 0.0,
          ObstacleType.drone: 0.1,
        }[type] ?? 0.0;
      case Biome.night:
        return const {
          ObstacleType.drone: 1.4,
          ObstacleType.building: 1.0,
          ObstacleType.hotAirBalloon: 0.9,
          ObstacleType.powerLine: 0.7,
          ObstacleType.kite: 0.5,
          ObstacleType.bird: 0.4,
          ObstacleType.stormCloud: 0.3,
          ObstacleType.treeBranch: 0.2,
          ObstacleType.windTurbine: 0.2,
        }[type] ?? 0.0;
      case Biome.atmosphere:
        return const {
          ObstacleType.hotAirBalloon: 1.3,
          ObstacleType.drone: 1.2,
          ObstacleType.windTurbine: 1.0,
          ObstacleType.stormCloud: 0.9,
          ObstacleType.kite: 0.6,
          ObstacleType.bird: 0.5,
          ObstacleType.powerLine: 0.2,
          ObstacleType.building: 0.1,
          ObstacleType.treeBranch: 0.0,
        }[type] ?? 0.0;
    }
  }
}

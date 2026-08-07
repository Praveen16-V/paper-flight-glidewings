import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';

/// How a trial's star rating is computed.
enum TrialStarMetric {
  /// Stars from the time left on the clock when the course is completed.
  /// Thresholds are seconds of remaining time.
  timeRemaining,

  /// Stars from the fraction of course coins collected.
  /// Thresholds are fractions (0.0–1.0).
  coinsPercent,
}

/// A scripted wind lane window (used by the Trial Director).
class ScriptedWindWindow {
  const ScriptedWindWindow({
    required this.startMeters,
    required this.endMeters,
    required this.laneIndex,
    required this.type,
    required this.intensity,
  });

  final double startMeters;
  final double endMeters;
  final int laneIndex;
  final WindType type;
  final double intensity;
}

/// A scripted turbulence pocket (used by the Trial Director).
class ScriptedTurbulence {
  const ScriptedTurbulence({
    required this.startMeters,
    required this.endMeters,
    required this.normX,
    required this.radius,
  });

  final double startMeters;
  final double endMeters;
  final double normX;
  final double radius;
}

/// One scripted spawn event in a trial course. [atMeters] is the distance at
/// which the element reaches the plane's row (the director converts it to a
/// spawn moment using the fixed course speed).
class TrialStep {
  const TrialStep({required this.atMeters, required this.items});
  final double atMeters;
  final List<TrialSpawn> items;
}

sealed class TrialSpawn {
  const TrialSpawn();
}

class TrialObstacleSpawn extends TrialSpawn {
  const TrialObstacleSpawn(this.type, {this.x = 195, this.gapCenterX, this.gapWidth, this.driftAmp, this.driftFreq, this.fromLeft});
  final ObstacleType type;

  /// Spawn x for point obstacles (bird, drone, turbine, balloon, cloud,
  /// kite). For gap obstacles the corridor centre is [gapCenterX].
  final double x;
  final double? gapCenterX;
  final double? gapWidth;
  final double? driftAmp;
  final double? driftFreq;
  final bool? fromLeft;
}

class TrialCoinSpawn extends TrialSpawn {
  const TrialCoinSpawn(this.x);
  final double x;
}

class TrialCoinLineSpawn extends TrialSpawn {
  const TrialCoinLineSpawn(this.x, {this.count = 5, this.spacing = 30});
  final double x;
  final int count;
  final double spacing;
}

class TrialCoinArcSpawn extends TrialSpawn {
  const TrialCoinArcSpawn(this.centerX, {this.radius = 70, this.count = 7});
  final double centerX;
  final double radius;
  final int count;
}

/// Immutable definition of a Precision Trial course.
class TrialDefinition {
  const TrialDefinition({
    required this.id,
    required this.title,
    required this.flavor,
    required this.objective,
    required this.biome,
    required this.scrollSpeedPxPerSec,
    required this.parSeconds,
    required this.totalCoins,
    required this.steps,
    required this.starMetric,
    required this.starThresholds,
    required this.icon,
    this.windScript = const [],
    this.turbulence = const [],
  });

  final int id;
  final String title;
  final String flavor;

  /// Short objective line shown in the HUD during the run.
  final String objective;
  final Biome biome;

  /// Fixed world scroll speed for this course (px/s). No ramping.
  final double scrollSpeedPxPerSec;

  /// Allowed time for the whole course. Null = no time limit.
  final double? parSeconds;

  /// Total coins planted in the course (for coin-percent stars).
  final int totalCoins;

  /// Scripted course content, ordered by [TrialStep.atMeters].
  final List<TrialStep> steps;
  final TrialStarMetric starMetric;

  /// [1★, 2★, 3★] thresholds for the metric (seconds left or coin fraction).
  final List<double> starThresholds;

  final String icon;

  /// Scripted wind lane windows (empty = natural noise wind, seeded).
  final List<ScriptedWindWindow> windScript;

  /// Scripted turbulence pockets, as (start, end) distance windows.
  final List<ScriptedTurbulence> turbulence;

  /// Distance (m) at which the run completes: after the last element has
  /// passed the plane row plus a trailing margin.
  double get courseEndMeters {
    double last = 0;
    for (final step in steps) {
      if (step.atMeters > last) last = step.atMeters;
    }
    return last + GameConfig.trialFinishMarginMeters;
  }

  /// Total coins a perfect run can collect.
  int countCoins() {
    var total = 0;
    for (final step in steps) {
      for (final item in step.items) {
        switch (item) {
          case TrialCoinSpawn():
            total += 1;
          case TrialCoinLineSpawn(:final count):
            total += count;
          case TrialCoinArcSpawn(:final count):
            total += count;
          case TrialObstacleSpawn():
            break;
        }
      }
    }
    return total;
  }

  /// Evaluates 0–3 stars from the metric value (seconds left or coin
  /// fraction). 1★ requires merely completing the course.
  int starsFor(double metricValue) {
    var stars = 1;
    if (metricValue >= starThresholds[1]) stars = 2;
    if (metricValue >= starThresholds[2]) stars = 3;
    return stars;
  }

  bool isUnlockedBy(int previousBestStars) => previousBestStars >= 1;
}

/// The six handcrafted Precision Trial courses.
abstract class TrialPool {
  static const List<TrialDefinition> all = [
    // ── 0 · Powerline Threading ──────────────────────────────────────────────
    TrialDefinition(
      id: 0,
      title: 'Powerline Threading',
      flavor: 'Narrow cables. Steady hands. Five gaps, no mercy.',
      objective: 'Thread 5 powerline gaps',
      icon: '🏗️',
      biome: Biome.city,
      scrollSpeedPxPerSec: 180,
      parSeconds: 25,
      totalCoins: 15,
      starMetric: TrialStarMetric.timeRemaining,
      starThresholds: [0, 2, 5],
      steps: [
        TrialStep(atMeters: 55, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 195, gapWidth: 84),
          TrialCoinLineSpawn(195, count: 3, spacing: 20),
        ]),
        TrialStep(atMeters: 120, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 120, gapWidth: 84),
          TrialCoinLineSpawn(120, count: 3, spacing: 20),
        ]),
        TrialStep(atMeters: 185, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 270, gapWidth: 84),
          TrialCoinLineSpawn(270, count: 3, spacing: 20),
        ]),
        TrialStep(atMeters: 250, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 150, gapWidth: 84),
          TrialCoinLineSpawn(150, count: 3, spacing: 20),
        ]),
        TrialStep(atMeters: 315, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 240, gapWidth: 84),
          TrialCoinLineSpawn(240, count: 3, spacing: 20),
        ]),
      ],
    ),

    // ── 1 · Coin Canyon ──────────────────────────────────────────────────────
    TrialDefinition(
      id: 1,
      title: 'Coin Canyon',
      flavor: 'A turbulent canyon. Every single coin counts.',
      objective: 'Collect 100% of the coins',
      icon: '🏔️',
      biome: Biome.mountain,
      scrollSpeedPxPerSec: 170,
      parSeconds: null,
      totalCoins: 28,
      starMetric: TrialStarMetric.coinsPercent,
      starThresholds: [0.6, 0.85, 1.0],
      windScript: [
        ScriptedWindWindow(startMeters: 80, endMeters: 200, laneIndex: 1, type: WindType.turbulent, intensity: 0.55),
        ScriptedWindWindow(startMeters: 200, endMeters: 320, laneIndex: 2, type: WindType.turbulent, intensity: 0.55),
        ScriptedWindWindow(startMeters: 320, endMeters: 440, laneIndex: 1, type: WindType.turbulent, intensity: 0.55),
      ],
      turbulence: [
        ScriptedTurbulence(startMeters: 80, endMeters: 200, normX: 0.30, radius: 0.15),
        ScriptedTurbulence(startMeters: 200, endMeters: 320, normX: 0.70, radius: 0.14),
        ScriptedTurbulence(startMeters: 320, endMeters: 440, normX: 0.45, radius: 0.17),
      ],
      steps: [
        TrialStep(atMeters: 90, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 300, driftAmp: 0),
          TrialCoinArcSpawn(130, radius: 70, count: 7),
        ]),
        TrialStep(atMeters: 160, items: [
          TrialCoinLineSpawn(250, count: 4, spacing: 32),
        ]),
        TrialStep(atMeters: 170, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 80, driftAmp: 0),
        ]),
        TrialStep(atMeters: 220, items: [
          TrialCoinArcSpawn(260, radius: 70, count: 7),
        ]),
        TrialStep(atMeters: 250, items: [
          TrialObstacleSpawn(ObstacleType.bird, x: 280, driftAmp: 45, driftFreq: 2.0),
        ]),
        TrialStep(atMeters: 280, items: [
          TrialCoinLineSpawn(90, count: 4, spacing: 32),
        ]),
        TrialStep(atMeters: 340, items: [
          TrialObstacleSpawn(ObstacleType.bird, x: 110, driftAmp: 40, driftFreq: 1.8),
        ]),
        TrialStep(atMeters: 350, items: [
          TrialCoinArcSpawn(150, radius: 70, count: 6),
        ]),
        TrialStep(atMeters: 400, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 290, driftAmp: 0),
        ]),
      ],
    ),

    // ── 2 · Skyscraper Slalom ────────────────────────────────────────────────
    TrialDefinition(
      id: 2,
      title: 'Skyscraper Slalom',
      flavor: 'Left. Right. Left. Don\'t clip the glass.',
      objective: 'Weave 8 building gaps fast',
      icon: '🏙️',
      biome: Biome.city,
      scrollSpeedPxPerSec: 200,
      parSeconds: 30,
      totalCoins: 24,
      starMetric: TrialStarMetric.timeRemaining,
      starThresholds: [0, 2, 5],
      steps: [
        TrialStep(atMeters: 60, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 130, gapWidth: 120),
          TrialCoinLineSpawn(130, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 115, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 260, gapWidth: 120),
          TrialCoinLineSpawn(260, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 170, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 130, gapWidth: 120),
          TrialCoinLineSpawn(130, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 225, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 260, gapWidth: 120),
          TrialCoinLineSpawn(260, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 280, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 130, gapWidth: 120),
          TrialCoinLineSpawn(130, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 335, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 260, gapWidth: 120),
          TrialCoinLineSpawn(260, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 390, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 130, gapWidth: 120),
          TrialCoinLineSpawn(130, count: 3, spacing: 22),
        ]),
        TrialStep(atMeters: 445, items: [
          TrialObstacleSpawn(ObstacleType.building, gapCenterX: 260, gapWidth: 120),
          TrialCoinLineSpawn(260, count: 3, spacing: 22),
        ]),
      ],
    ),

    // ── 3 · Feathered Gauntlet ───────────────────────────────────────────────
    TrialDefinition(
      id: 3,
      title: 'Feathered Gauntlet',
      flavor: 'Keep your cool among the flock and the branches.',
      objective: 'Weave 6 birds & branches',
      icon: '🦅',
      biome: Biome.backyard,
      scrollSpeedPxPerSec: 170,
      parSeconds: 28,
      totalCoins: 5,
      starMetric: TrialStarMetric.timeRemaining,
      starThresholds: [0, 2, 4],
      steps: [
        TrialStep(atMeters: 60, items: [
          TrialObstacleSpawn(ObstacleType.bird, x: 195, driftAmp: 45, driftFreq: 2.0),
        ]),
        TrialStep(atMeters: 90, items: [
          TrialCoinSpawn(290),
        ]),
        TrialStep(atMeters: 120, items: [
          TrialObstacleSpawn(ObstacleType.treeBranch, fromLeft: true),
        ]),
        TrialStep(atMeters: 150, items: [
          TrialCoinSpawn(100),
        ]),
        TrialStep(atMeters: 180, items: [
          TrialObstacleSpawn(ObstacleType.bird, x: 120, driftAmp: 50, driftFreq: 1.7),
        ]),
        TrialStep(atMeters: 210, items: [
          TrialCoinSpawn(290),
        ]),
        TrialStep(atMeters: 240, items: [
          TrialObstacleSpawn(ObstacleType.treeBranch, fromLeft: false),
        ]),
        TrialStep(atMeters: 270, items: [
          TrialCoinSpawn(100),
        ]),
        TrialStep(atMeters: 300, items: [
          TrialObstacleSpawn(ObstacleType.bird, x: 260, driftAmp: 40, driftFreq: 2.2),
        ]),
        TrialStep(atMeters: 330, items: [
          TrialCoinSpawn(290),
        ]),
        TrialStep(atMeters: 360, items: [
          TrialObstacleSpawn(ObstacleType.kite, x: 150, driftAmp: 0),
        ]),
      ],
    ),

    // ── 4 · Thermal Summit ───────────────────────────────────────────────────
    TrialDefinition(
      id: 4,
      title: 'Thermal Summit',
      flavor: 'Chain four thermals to the summit.',
      objective: 'Ride 4 thermals to the summit',
      icon: '🎈',
      biome: Biome.mountain,
      scrollSpeedPxPerSec: 160,
      parSeconds: 30,
      totalCoins: 16,
      starMetric: TrialStarMetric.timeRemaining,
      starThresholds: [0, 3, 5],
      windScript: [
        ScriptedWindWindow(startMeters: 40, endMeters: 110, laneIndex: 0, type: WindType.thermal, intensity: 0.9),
        ScriptedWindWindow(startMeters: 120, endMeters: 190, laneIndex: 2, type: WindType.thermal, intensity: 0.9),
        ScriptedWindWindow(startMeters: 200, endMeters: 270, laneIndex: 1, type: WindType.thermal, intensity: 0.9),
        ScriptedWindWindow(startMeters: 280, endMeters: 350, laneIndex: 3, type: WindType.thermal, intensity: 0.9),
      ],
      steps: [
        TrialStep(atMeters: 70, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 300, driftAmp: 0),
          TrialCoinLineSpawn(60, count: 4, spacing: 28),
        ]),
        TrialStep(atMeters: 150, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 70, driftAmp: 0),
          TrialCoinLineSpawn(250, count: 4, spacing: 28),
        ]),
        TrialStep(atMeters: 220, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 290, driftAmp: 0),
          TrialCoinLineSpawn(150, count: 4, spacing: 28),
        ]),
        TrialStep(atMeters: 300, items: [
          TrialObstacleSpawn(ObstacleType.windTurbine, x: 70, driftAmp: 0),
          TrialCoinLineSpawn(330, count: 4, spacing: 28),
        ]),
      ],
    ),

    // ── 5 · Storm Sprint ─────────────────────────────────────────────────────
    TrialDefinition(
      id: 5,
      title: 'Storm Sprint',
      flavor: 'Lightning, rain, and no mercy.',
      objective: 'Sprint through the storm',
      icon: '⛈️',
      biome: Biome.storm,
      scrollSpeedPxPerSec: 220,
      parSeconds: 26,
      totalCoins: 5,
      starMetric: TrialStarMetric.timeRemaining,
      starThresholds: [0, 2, 5],
      steps: [
        TrialStep(atMeters: 70, items: [
          TrialObstacleSpawn(ObstacleType.stormCloud, x: 100),
        ]),
        TrialStep(atMeters: 105, items: [
          TrialCoinSpawn(290),
        ]),
        TrialStep(atMeters: 140, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 150, gapWidth: 100),
        ]),
        TrialStep(atMeters: 175, items: [
          TrialCoinSpawn(90),
        ]),
        TrialStep(atMeters: 210, items: [
          TrialObstacleSpawn(ObstacleType.stormCloud, x: 260),
        ]),
        TrialStep(atMeters: 245, items: [
          TrialCoinSpawn(290),
        ]),
        TrialStep(atMeters: 280, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 220, gapWidth: 96),
        ]),
        TrialStep(atMeters: 315, items: [
          TrialCoinSpawn(90),
        ]),
        TrialStep(atMeters: 350, items: [
          TrialObstacleSpawn(ObstacleType.powerLine, gapCenterX: 120, gapWidth: 90),
        ]),
        TrialStep(atMeters: 385, items: [
          TrialCoinSpawn(290),
        ]),
        TrialStep(atMeters: 420, items: [
          TrialObstacleSpawn(ObstacleType.stormCloud, x: 180),
        ]),
      ],
    ),
  ];

  static TrialDefinition? byId(int id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}

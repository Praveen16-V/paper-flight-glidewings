/// All enums for Paper Flight — kept in one file for easy cross-reference.

import 'package:flutter/material.dart';

import '../constants/game_config.dart';
import '../widgets/paper_icons.dart';

// ── Game State ──────────────────────────────────────────────────────────────

enum GamePhase {
  idle,      // before run starts
  playing,   // active run
  paused,    // tapped pause
  dying,     // crash freeze frame
  gameOver,  // transition to results screen
  reviving,  // watching rewarded ad to revive
}

// ── Game Modes (Task 8) ─────────────────────────────────────────────────────

enum GameMode {
  classic, // endless arcade — the original mode
  zen,     // Zen Flight: no crash deaths, calm skies, infinite gliding
  daily,   // Daily Seeded Flight: one seeded run per UTC day, same for everyone
  trial,   // Precision Flight: handcrafted puzzle courses with star ratings
}

extension GameModeLabel on GameMode {
  String get displayName {
    switch (this) {
      case GameMode.classic:
        return 'Classic Flight';
      case GameMode.zen:
        return 'Zen Flight';
      case GameMode.daily:
        return 'Daily Seeded';
      case GameMode.trial:
        return 'Precision Trial';
    }
  }

  String get tagline {
    switch (this) {
      case GameMode.classic:
        return 'Endless arcade. One tap, infinite falls.';
      case GameMode.zen:
        return 'No crashes. Calm skies. Just glide.';
      case GameMode.daily:
        return 'One run a day — same wind for everyone.';
      case GameMode.trial:
        return 'Handcrafted courses. Earn your stars.';
    }
  }

  String get icon {
    switch (this) {
      case GameMode.classic:
        return '✈️';
      case GameMode.zen:
        return '🍃';
      case GameMode.daily:
        return '🗓️';
      case GameMode.trial:
        return '🎯';
    }
  }

  /// The custom paper-craft vector icon for this mode.
  PaperIconData get paperIcon {
    switch (this) {
      case GameMode.classic:
        return PaperIconData.glider;
      case GameMode.zen:
        return PaperIconData.leaf;
      case GameMode.daily:
        return PaperIconData.calendar;
      case GameMode.trial:
        return PaperIconData.bullseye;
    }
  }

  /// The tinted paper-sheet colour used for this mode's card.
  Color get paperColor {
    switch (this) {
      case GameMode.classic:
        return const Color(0xFFF6E3AE);
      case GameMode.zen:
        return const Color(0xFFD9EDD6);
      case GameMode.daily:
        return const Color(0xFFDCEBF4);
      case GameMode.trial:
        return const Color(0xFFF6DAD2);
    }
  }

  /// Whether this mode touches the shared coin/gem economy or challenge
  /// objectives. Task 8 design: Zen and Trials are pure gameplay; the Daily
  /// awards a leaderboard rank — none of them bank coins.
  bool get isEconomyRun => this == GameMode.classic;
}

// ── Biomes ───────────────────────────────────────────────────────────────────

enum Biome {
  backyard,    // tutorial, calm
  city,        // buildings, power lines, pigeons
  storm,       // rain, lightning, strong gusts
  mountain,    // thermals, birds of prey, canyon
  night,       // drones, spotlights, firefly coins
  atmosphere,  // endgame — meteors, thin air
}

extension BiomeLabel on Biome {
  String get displayName {
    switch (this) {
      case Biome.backyard:
        return 'Backyard Morning';
      case Biome.city:
        return 'City Rooftops';
      case Biome.storm:
        return 'Storm Front';
      case Biome.mountain:
        return 'Mountain Pass';
      case Biome.night:
        return 'Night Sky';
      case Biome.atmosphere:
        return 'Edge of Atmosphere';
    }
  }
}

// ── Obstacles ────────────────────────────────────────────────────────────────

enum ObstacleType {
  powerLine,      // static/sagging catenary with electrical sparks & warning flags
  building,       // skyline buildings with animated rooftop fans, water towers, spires
  treeBranch,     // organic wind-swaying foliage with leaf flutter & falling leaf particles
  bird,           // dynamic flapping avian with realistic wing cycles, banking & swooping
  drone,          // dynamic quadcopter with spinning rotors, searchlight beam & alert LED
  windTurbine,    // dynamic giant 3-blade rotating wind turbine / paper pinwheel
  hotAirBalloon,  // dynamic floating hot air balloon with animated burner flame & wicker basket
  stormCloud,     // dynamic billowing thundercloud with electric discharge arcs & rain
  kite,           // dynamic fluttering festival kite with dynamic physics ribbon tail
}

extension ObstacleLabel on ObstacleType {
  String get displayName {
    switch (this) {
      case ObstacleType.powerLine:
        return 'Power Line';
      case ObstacleType.building:
        return 'Skyscraper Rooftop';
      case ObstacleType.treeBranch:
        return 'Tree Canopy';
      case ObstacleType.bird:
        return 'Swooping Bird';
      case ObstacleType.drone:
        return 'Surveillance Drone';
      case ObstacleType.windTurbine:
        return 'Wind Turbine';
      case ObstacleType.hotAirBalloon:
        return 'Hot Air Balloon';
      case ObstacleType.stormCloud:
        return 'Thundercloud';
      case ObstacleType.kite:
        return 'Festival Kite';
    }
  }

  String get assetName {
    switch (this) {
      case ObstacleType.powerLine:
        return 'power_line';
      case ObstacleType.building:
        return 'building';
      case ObstacleType.treeBranch:
        return 'tree_branch';
      case ObstacleType.bird:
        return 'bird';
      case ObstacleType.drone:
        return 'drone';
      case ObstacleType.windTurbine:
        return 'wind_turbine';
      case ObstacleType.hotAirBalloon:
        return 'hot_air_balloon';
      case ObstacleType.stormCloud:
        return 'storm_cloud';
      case ObstacleType.kite:
        return 'kite';
    }
  }

  /// True for organic/nature obstacles — used by Crane's brush-off.
  bool get isOrganic => this == ObstacleType.treeBranch;

  /// True for building gap obstacles — used for challenge tracking.
  bool get isBuildingGap => this == ObstacleType.building;
}

// ── Power-ups ─────────────────────────────────────────────────────────────────

enum PowerUpType {
  shield,
  magnet,
  ghost,
  slowMo,
  coinRush,
}

extension PowerUpLabel on PowerUpType {
  String get displayName {
    switch (this) {
      case PowerUpType.shield:
        return 'Shield';
      case PowerUpType.magnet:
        return 'Magnet';
      case PowerUpType.ghost:
        return 'Ghost';
      case PowerUpType.slowMo:
        return 'Slow-Mo';
      case PowerUpType.coinRush:
        return 'Coin Rush';
    }
  }

  String get assetName {
    switch (this) {
      case PowerUpType.shield:
        return 'shield';
      case PowerUpType.magnet:
        return 'magnet';
      case PowerUpType.ghost:
        return 'ghost';
      case PowerUpType.slowMo:
        return 'slowmo';
      case PowerUpType.coinRush:
        return 'coin_rush';
    }
  }
}

// ── Plane Types ───────────────────────────────────────────────────────────────

enum PlaneType {
  dart,       // starter, balanced + distance bonus
  glider,     // wider turn radius, gentle drift — coin earner + thermals
  stuntFold,  // tighter turn radius, slightly higher fall speed — skill plane
  crane,      // origami crane — forgives one tree branch per run
  stealthJet, // stealth jet — tiny hitbox, fast dive recovery
}

extension PlaneLabel on PlaneType {
  String get displayName {
    switch (this) {
      case PlaneType.dart:
        return 'Paper Dart';
      case PlaneType.glider:
        return 'Glider Fold';
      case PlaneType.stuntFold:
        return 'Stunt Fold';
      case PlaneType.crane:
        return 'Origami Crane';
      case PlaneType.stealthJet:
        return 'Stealth Jet';
    }
  }

  String get assetName {
    switch (this) {
      case PlaneType.dart:
        return 'dart';
      case PlaneType.glider:
        return 'glider';
      case PlaneType.stuntFold:
        return 'stunt_fold';
      case PlaneType.crane:
        return 'crane';
      case PlaneType.stealthJet:
        return 'stealth_jet';
    }
  }

  /// One-line flavour for the hangar card.
  String get tagline {
    switch (this) {
      case PlaneType.dart:
        return 'Reliable starter — +15% distance score';
      case PlaneType.glider:
        return 'Floats longer, attracts coins, +20% thermal';
      case PlaneType.stuntFold:
        return 'Snappy turns, double snap, +50% near-miss';
      case PlaneType.crane:
        return 'Graceful — 1 free tree branch brush-off';
      case PlaneType.stealthJet:
        return 'Slim hitbox, dives recover instantly';
    }
  }

  /// Short trait bullets for hangar detail sheet.
  List<String> get traitBullets {
    switch (this) {
      case PlaneType.dart:
        return ['+15% distance score', 'Balanced handling', 'BOOST burst'];
      case PlaneType.glider:
        return [
          'Weak coin attraction',
          'Wider glide arc',
          '+20% thermal float',
        ];
      case PlaneType.stuntFold:
        return [
          'Snappy turns',
          '2× snap recharge',
          '+50% near-miss score',
        ];
      case PlaneType.crane:
        return [
          '1 free tree brush-off / run',
          'Gentle fall curve',
          'Forgives organic branches',
        ];
      case PlaneType.stealthJet:
        return [
          'Smaller hitbox (~24% tighter)',
          'Faster dive recovery',
          'Enhanced wind control',
        ];
    }
  }

  /// Coin cost to unlock. Dart is free (starter).
  int get unlockCost {
    switch (this) {
      case PlaneType.dart:
        return 0;
      case PlaneType.glider:
        return 500;
      case PlaneType.stuntFold:
        return 1200;
      case PlaneType.crane:
        return 1800;
      case PlaneType.stealthJet:
        return 3000;
    }
  }

  /// Gem cost to unlock (premium planes may require gems alongside coins).
  int get unlockGemCost {
    switch (this) {
      case PlaneType.dart:
      case PlaneType.glider:
      case PlaneType.stuntFold:
      case PlaneType.crane:
        return 0;
      case PlaneType.stealthJet:
        return 5;
    }
  }

  /// Stat deltas vs. baseline — small and cosmetic-leaning per GDD.
  double get turnSpeedMultiplier {
    switch (this) {
      case PlaneType.dart:
        return 1.0;
      case PlaneType.glider:
        return 0.85; // gentler turns
      case PlaneType.stuntFold:
        return 1.15; // snappier
      case PlaneType.crane:
        return 0.95; // graceful, slightly soft
      case PlaneType.stealthJet:
        return 1.10; // responsive but not twitchy
    }
  }

  double get fallSpeedMultiplier {
    switch (this) {
      case PlaneType.dart:
        return 1.0;
      case PlaneType.glider:
        return 0.90; // slightly slower fall
      case PlaneType.stuntFold:
        return 1.10; // slightly faster fall
      case PlaneType.crane:
        return 0.88; // lightest — hangs in air
      case PlaneType.stealthJet:
        return 1.05; // recovers quickly, not plummeting
    }
  }

  /// Per-plane hitbox scale override (null → use global default).
  double? get hitboxScaleOverride {
    switch (this) {
      case PlaneType.stealthJet:
        return GameConfig.stealthHitboxScale;
      default:
        return null;
    }
  }
}

/// Signature power-up each plane carries, fired by the flick-up / double-tap
/// gesture when the "flick to use power-up" setting is enabled.
///
/// The trigger is generic — the gesture no longer hard-wires to the paper-snap
/// BOOST burst; each plane activates its own action instead.
extension PlanePowerUp on PlaneType {
  /// True when this plane's signature action is the paper-snap BOOST burst
  /// (charge-based, no timer) rather than a timed power-up.
  bool get usesBoostAsSignatureAction => this == PlaneType.dart || this == PlaneType.crane;

  /// The timed power-up this plane carries. Only meaningful when
  /// [usesBoostAsSignatureAction] is false (the dart/crane fall back to BOOST).
  PowerUpType get signaturePowerUp {
    switch (this) {
      case PlaneType.dart:
      case PlaneType.crane:
        // Unused (fires BOOST burst) — kept for exhaustiveness.
        return PowerUpType.magnet;
      case PlaneType.glider:
        // Coin-earner: pull nearby coins toward the plane.
        return PowerUpType.magnet;
      case PlaneType.stuntFold:
        // Skill plane: phase through obstacles.
        return PowerUpType.ghost;
      case PlaneType.stealthJet:
        // Speed plane: briefly slow the world to thread gaps.
        return PowerUpType.slowMo;
    }
  }

  /// Ability summary for tooltips.
  String get signatureActionLabel {
    if (usesBoostAsSignatureAction) return 'BOOST burst';
    return signaturePowerUp.displayName;
  }
}

// ── Paper Skins ───────────────────────────────────────────────────────────────

enum PaperSkin {
  plain,          // default white
  newspaper,      // newspaper print
  graphPaper,     // light blue grid
  notebookDoodle, // ruled paper + doodles
  holographicFoil,// iridescent foil
  watercolorWash, // pastel wash
  goldLeaf,       // metallic gold
}

extension PaperSkinLabel on PaperSkin {
  String get displayName {
    switch (this) {
      case PaperSkin.plain:
        return 'Plain Paper';
      case PaperSkin.newspaper:
        return 'Newspaper Print';
      case PaperSkin.graphPaper:
        return 'Graph Paper';
      case PaperSkin.notebookDoodle:
        return 'Notebook Doodle';
      case PaperSkin.holographicFoil:
        return 'Holographic Foil';
      case PaperSkin.watercolorWash:
        return 'Watercolor Wash';
      case PaperSkin.goldLeaf:
        return 'Gold Leaf';
    }
  }

  String get description {
    switch (this) {
      case PaperSkin.plain:
        return 'Classic white — clean and crisp';
      case PaperSkin.newspaper:
        return 'Vintage newsprint with headlines';
      case PaperSkin.graphPaper:
        return 'Engineer\'s blue grid';
      case PaperSkin.notebookDoodle:
        return 'Ruled lines + margin doodles';
      case PaperSkin.holographicFoil:
        return 'Shimmering iridescent foil';
      case PaperSkin.watercolorWash:
        return 'Soft pastel watercolor';
      case PaperSkin.goldLeaf:
        return 'Luxurious metallic gold';
    }
  }

  int get unlockCostCoins {
    switch (this) {
      case PaperSkin.plain:
        return 0;
      case PaperSkin.newspaper:
        return 750;
      case PaperSkin.graphPaper:
        return 600;
      case PaperSkin.notebookDoodle:
        return 900;
      case PaperSkin.holographicFoil:
        return 2000;
      case PaperSkin.watercolorWash:
        return 1200;
      case PaperSkin.goldLeaf:
        return 3000;
    }
  }

  int get unlockCostGems {
    switch (this) {
      case PaperSkin.plain:
      case PaperSkin.newspaper:
      case PaperSkin.graphPaper:
      case PaperSkin.notebookDoodle:
        return 0;
      case PaperSkin.holographicFoil:
        return 3;
      case PaperSkin.watercolorWash:
        return 0;
      case PaperSkin.goldLeaf:
        return 8;
    }
  }

  /// Primary tint for procedural rendering.
  int get baseColorHex {
    switch (this) {
      case PaperSkin.plain:
        return 0xFFF5A623;
      case PaperSkin.newspaper:
        return 0xFFE8E0D0;
      case PaperSkin.graphPaper:
        return 0xFFB8E0F0;
      case PaperSkin.notebookDoodle:
        return 0xFFFFF8E1;
      case PaperSkin.holographicFoil:
        return 0xFFCE93D8;
      case PaperSkin.watercolorWash:
        return 0xFFB2EBF2;
      case PaperSkin.goldLeaf:
        return 0xFFFFD700;
    }
  }
}

// ── Challenge System ────────────────────────────────────────────────────────

enum ChallengePeriod { daily, weekly }

enum ChallengeType {
  rideThermalsSingleRun,   // e.g. ride 3 thermals in one run
  coinComboInBiome,        // e.g. 8× combo in Storm
  skyscraperGapsNoPowerUp, // e.g. 10 building gaps without power-up
  collectCoinsSingleRun,   // e.g. 50 coins in one run
  collectCoinsTotal,       // cumulative coins
  nearMissesSingleRun,     // e.g. 5 near misses in one run
  nearMissesTotal,         // cumulative
  travelDistanceSingleRun, // e.g. 1500m in one run
  travelDistanceTotal,     // cumulative weekly
  surviveRuns,             // play N runs
  usePowerUps,             // use N power-ups
  buildingGapsTotal,       // cumulative gaps
  rideThermalsTotal,       // cumulative thermals
}

// ── Wind ─────────────────────────────────────────────────────────────────────

enum WindType {
  calm,
  leftPush,
  rightPush,
  turbulent,
  thermal, // updraft
}

// ── Near-Miss Tiers ───────────────────────────────────────────────────────────

/// Progressive risk tiers for near-misses, tightest pass pays the most.
enum NearMissTier {
  closeShave,   // within 32px edge clearance — +25
  hairThin,     // within 18px edge clearance — +50, pitch-shifted sting
  deathDefying, // within  8px edge clearance — +100, freeze frame + camera pulse
}

extension NearMissTierInfo on NearMissTier {
  String get label {
    switch (this) {
      case NearMissTier.closeShave:
        return 'CLOSE SHAVE!';
      case NearMissTier.hairThin:
        return 'HAIR-THIN!';
      case NearMissTier.deathDefying:
        return 'DEATH DEFYING!';
    }
  }

  /// Points awarded for a pass at this tier.
  int get points {
    switch (this) {
      case NearMissTier.closeShave:
        return GameConfig.nearMissCloseShavePoints;
      case NearMissTier.hairThin:
        return GameConfig.nearMissHairThinPoints;
      case NearMissTier.deathDefying:
        return GameConfig.nearMissDeathDefyingPoints;
    }
  }

  /// Playback rate for the near-miss sting — Hair-Thin pitches up for a
  /// sharper sting, Death Defying drops low for a heavier hit.
  double get stingPlaybackRate {
    switch (this) {
      case NearMissTier.closeShave:
        return 1.0;
      case NearMissTier.hairThin:
        return 1.35;
      case NearMissTier.deathDefying:
        return 0.72;
    }
  }
}

/// Maps an edge clearance (px between hitboxes) to its risk tier.
/// Returns null when the pass was too wide to score.
NearMissTier? nearMissTierForClearance(double clearance) {
  if (clearance <= GameConfig.nearMissDeathDefyingDistance) {
    return NearMissTier.deathDefying;
  }
  if (clearance <= GameConfig.nearMissHairThinDistance) {
    return NearMissTier.hairThin;
  }
  if (clearance <= GameConfig.nearMissCloseShaveDistance) {
    return NearMissTier.closeShave;
  }
  return null;
}

// ── Control Scheme ────────────────────────────────────────────────────────────

enum ControlScheme {
  tilt,          // default: accelerometer tilt for L/R
  touchZones,    // alt: on-screen left/right tap zones
  joystick,      // floating virtual joystick: thumb deflects to steer, hold controls altitude
}

// ── Collectible ────────────────────────────────────────────────────────────────

enum CollectibleType {
  coin,
  gem,
}

// ── Ad Type ───────────────────────────────────────────────────────────────────

enum AdPlacement {
  revive,          // rewarded — revive after crash
  doubleCoins,     // rewarded — double end-run coins
  mysteryChest,    // rewarded — unlock bonus chest
  refillShield,    // rewarded — pre-run shield
  gameOver,        // interstitial — natural game-over break
}

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

/// Gameplay signals forwarded from the plane to its active paper-skin painter.
enum SkinGameEvent {
  coinCollected,
  nearMiss,
  shieldHit,
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
  ocean,       // moonlit open water, whale breaches and sea spray
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
      case Biome.ocean:
        return 'Moonlit Ocean';
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
  trafficPlane,   // oncoming paper airplane traffic flying opposite direction
  fireworks,      // ascending firework rocket bursting into popping star bursts
  weatherBalloon, // satellite dish & tethered weather probe balloon cluster
  clothesline,    // backyard clothesline with fluttering paper dolls & clothespins
  windsock,       // aviation windsock cone pointing in direction of local wind
  lightningStrike,// telegraphed vertical lightning bolt
  meteorShower,   // atmosphere cluster with warning shadows
  tornado,        // rotating wind column that pulls the plane
  flockMigration, // 10–20 birds crossing in a V formation
  whaleBreach,    // massive slow ocean hazard with splash particles
  paperDragon,    // serpentine multi-segment paper boss
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
      case ObstacleType.trafficPlane:
        return 'Air Traffic';
      case ObstacleType.fireworks:
        return 'Fireworks Burst';
      case ObstacleType.weatherBalloon:
        return 'Weather Cluster';
      case ObstacleType.clothesline:
        return 'Paper Clothesline';
      case ObstacleType.windsock:
        return 'Airfield Windsock';
      case ObstacleType.lightningStrike:
        return 'Lightning Strike';
      case ObstacleType.meteorShower:
        return 'Meteor Shower';
      case ObstacleType.tornado:
        return 'Tornado';
      case ObstacleType.flockMigration:
        return 'Flock Migration';
      case ObstacleType.whaleBreach:
        return 'Whale Breach';
      case ObstacleType.paperDragon:
        return 'Paper Dragon';
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
      case ObstacleType.trafficPlane:
        return 'traffic_plane';
      case ObstacleType.fireworks:
        return 'fireworks';
      case ObstacleType.weatherBalloon:
        return 'weather_balloon';
      case ObstacleType.clothesline:
        return 'clothesline';
      case ObstacleType.windsock:
        return 'windsock';
      case ObstacleType.lightningStrike:
        return 'lightning_strike';
      case ObstacleType.meteorShower:
        return 'meteor_shower';
      case ObstacleType.tornado:
        return 'tornado';
      case ObstacleType.flockMigration:
        return 'flock_migration';
      case ObstacleType.whaleBreach:
        return 'whale_breach';
      case ObstacleType.paperDragon:
        return 'paper_dragon';
    }
  }

  /// True for organic/nature obstacles — used by Crane's brush-off.
  bool get isOrganic => this == ObstacleType.treeBranch;

  /// True for building gap obstacles — used for challenge tracking.
  bool get isBuildingGap => this == ObstacleType.building;

  /// Firework rockets are the current projectile-class hazard that Shield Lv2
  /// can reflect instead of consuming the shield.
  bool get isReflectableProjectile => this == ObstacleType.fireworks;

  /// Boss passes reserve the sky so their telegraph and route remain readable.
  bool get isBoss => this == ObstacleType.paperDragon;

  /// Obstacles that answer the paper-snap interaction pulse instead of only
  /// being dodged. More interaction families can join this taxonomy later.
  bool get isSnapInteractive => this == ObstacleType.kite;

  /// Breakable paper/technology hazards with a small visible integrity budget.
  /// Drones need two deliberate snap hits; balloons and fireworks are fragile.
  int get destructibleHitPoints {
    switch (this) {
      case ObstacleType.drone:
        return 2;
      case ObstacleType.hotAirBalloon:
      case ObstacleType.fireworks:
      case ObstacleType.weatherBalloon:
        return 1;
      default:
        return 0;
    }
  }

  bool get isDestructible => destructibleHitPoints > 0;

  /// Dynamic hazards vulnerable to Cursed Magnet's dangerous pull.
  bool get isCursedMagnetAttractable =>
      this == ObstacleType.bird ||
      this == ObstacleType.drone ||
      this == ObstacleType.kite ||
      this == ObstacleType.trafficPlane ||
      this == ObstacleType.fireworks ||
      this == ObstacleType.weatherBalloon ||
      this == ObstacleType.hotAirBalloon;

  /// Small, individual hazards the Black Hole vacuum can drag in and swallow.
  /// Full-width gates, bosses and oncoming traffic stay immune so the vortex
  /// remains a tactical clear instead of an unconditional screen wipe.
  bool get isBlackHoleVacuumable =>
      this == ObstacleType.bird ||
      this == ObstacleType.drone ||
      this == ObstacleType.kite ||
      this == ObstacleType.fireworks ||
      this == ObstacleType.weatherBalloon ||
      this == ObstacleType.hotAirBalloon;
}

/// A hand-authored, readable two-obstacle encounter. These are not random
/// overlap: the spawner reserves a planned safe corridor and staggers the
/// pair so pilots can learn the pattern before it reaches the plane row.
enum ObstacleCombination {
  cityTrafficStack,
  stormCrossfire,
  rotorRun,
  kiteRelay,
}

extension ObstacleCombinationLabel on ObstacleCombination {
  String get displayName {
    switch (this) {
      case ObstacleCombination.cityTrafficStack:
        return 'City Traffic Stack';
      case ObstacleCombination.stormCrossfire:
        return 'Storm Crossfire';
      case ObstacleCombination.rotorRun:
        return 'Rotor Run';
      case ObstacleCombination.kiteRelay:
        return 'Kite Relay';
    }
  }

  /// The lead and trailing members, in their authored encounter order.
  List<ObstacleType> get members {
    switch (this) {
      case ObstacleCombination.cityTrafficStack:
        return const [ObstacleType.drone, ObstacleType.trafficPlane];
      case ObstacleCombination.stormCrossfire:
        return const [ObstacleType.stormCloud, ObstacleType.lightningStrike];
      case ObstacleCombination.rotorRun:
        return const [ObstacleType.windTurbine, ObstacleType.bird];
      case ObstacleCombination.kiteRelay:
        return const [ObstacleType.windsock, ObstacleType.kite];
    }
  }
}

/// A local interaction between two complementary hazards. Unlike a spawn
/// combination, a synergy may also emerge from procedural overlap; each member
/// exposes a small, readable behaviour change while the link is active.
enum ObstacleSynergy {
  stormCharge,
  droneTrafficLink,
  rotorWake,
  windTether,
}

extension ObstacleSynergyLabel on ObstacleSynergy {
  String get displayName {
    switch (this) {
      case ObstacleSynergy.stormCharge:
        return 'Storm Charge';
      case ObstacleSynergy.droneTrafficLink:
        return 'Drone Traffic Link';
      case ObstacleSynergy.rotorWake:
        return 'Rotor Wake';
      case ObstacleSynergy.windTether:
        return 'Wind Tether';
    }
  }

  List<ObstacleType> get members {
    switch (this) {
      case ObstacleSynergy.stormCharge:
        return const [ObstacleType.stormCloud, ObstacleType.lightningStrike];
      case ObstacleSynergy.droneTrafficLink:
        return const [ObstacleType.drone, ObstacleType.trafficPlane];
      case ObstacleSynergy.rotorWake:
        return const [ObstacleType.windTurbine, ObstacleType.bird];
      case ObstacleSynergy.windTether:
        return const [ObstacleType.windsock, ObstacleType.kite];
    }
  }

  Color get color {
    switch (this) {
      case ObstacleSynergy.stormCharge:
        return const Color(0xFFFFF176);
      case ObstacleSynergy.droneTrafficLink:
        return const Color(0xFF80DEEA);
      case ObstacleSynergy.rotorWake:
        return const Color(0xFFB9F6CA);
      case ObstacleSynergy.windTether:
        return const Color(0xFFB2EBF2);
    }
  }
}

/// Visual grammar for an off-screen hazard announcement. The component draws
/// a shared arrival dial, then uses this profile to preview the collision shape
/// or route before the physical obstacle enters the viewport.
enum ObstacleTelegraphStyle {
  pinpoint,
  trajectory,
  lane,
  area,
  formation,
  gate,
  boss,
}

extension ObstacleTelegraphProfile on ObstacleType {
  ObstacleTelegraphStyle get telegraphStyle {
    switch (this) {
      case ObstacleType.powerLine:
      case ObstacleType.building:
      case ObstacleType.clothesline:
        return ObstacleTelegraphStyle.gate;
      case ObstacleType.lightningStrike:
        return ObstacleTelegraphStyle.lane;
      case ObstacleType.meteorShower:
      case ObstacleType.tornado:
      case ObstacleType.stormCloud:
      case ObstacleType.whaleBreach:
        return ObstacleTelegraphStyle.area;
      case ObstacleType.flockMigration:
        return ObstacleTelegraphStyle.formation;
      case ObstacleType.paperDragon:
        return ObstacleTelegraphStyle.boss;
      case ObstacleType.bird:
      case ObstacleType.drone:
      case ObstacleType.windTurbine:
      case ObstacleType.hotAirBalloon:
      case ObstacleType.kite:
      case ObstacleType.trafficPlane:
      case ObstacleType.fireworks:
      case ObstacleType.weatherBalloon:
      case ObstacleType.windsock:
        return ObstacleTelegraphStyle.trajectory;
      case ObstacleType.treeBranch:
        return ObstacleTelegraphStyle.pinpoint;
    }
  }
}

// ── Power-ups ─────────────────────────────────────────────────────────────────

enum PowerUpType {
  shield,      // absorbs hits
  magnet,      // pulls coins
  ghost,       // phase through obstacles
  slowMo,      // time slows down
  coinRush,    // 2x coin value + coin shower
  doubleScore, // 2x distance meters score (jet exhaust flame)
  shrink,      // compact micro-fold hitbox 0.35
  windCaller,  // calm adverse wind, compass & thermals
  decoyClone,  // 2 ghost decoy planes absorb next 2 hits
  blackHole,   // cosmic vortex vacuums coins + small obstacles
  turboDash,   // short invincible blazing thrust dash
}

extension PowerUpLabel on PowerUpType {
  /// Timed effects are stored as charges and manually fired as a short burst.
  bool get isChargeBased => switch (this) {
        PowerUpType.magnet ||
        PowerUpType.ghost ||
        PowerUpType.slowMo ||
        PowerUpType.coinRush ||
        PowerUpType.doubleScore ||
        PowerUpType.shrink ||
        PowerUpType.windCaller ||
        PowerUpType.blackHole ||
        PowerUpType.turboDash => true,
        PowerUpType.shield || PowerUpType.decoyClone => false,
      };

  /// Hangar-evolvable effects currently supported by the live game loop.
  bool get hasEvolution =>
      this == PowerUpType.magnet || this == PowerUpType.shield;

  int evolutionCost(int toLevel) {
    if (toLevel != 2) return 0;
    switch (this) {
      case PowerUpType.magnet:
        return GameConfig.magnetEvolutionLevel2Cost;
      case PowerUpType.shield:
        return GameConfig.shieldEvolutionLevel2Cost;
      default:
        return 0;
    }
  }

  String evolutionDescription(int level) {
    switch (this) {
      case PowerUpType.magnet:
        return level >= 2
            ? 'Lv2 • 245px pull + auto-collect gems'
            : 'Lv1 • Standard coin pull';
      case PowerUpType.shield:
        return level >= 2
            ? 'Lv2 • Reflects firework projectiles'
            : 'Lv1 • Absorbs one impact';
      default:
        return 'No evolution installed';
    }
  }

  Color get visualColor {
    switch (this) {
      case PowerUpType.shield:
        return const Color(0xFF64B5F6);
      case PowerUpType.magnet:
        return const Color(0xFFAB47BC);
      case PowerUpType.ghost:
        return const Color(0xFF80DEEA);
      case PowerUpType.slowMo:
        return const Color(0xFF64FFDA);
      case PowerUpType.coinRush:
        return const Color(0xFFFFD740);
      case PowerUpType.doubleScore:
        return const Color(0xFFFF7043);
      case PowerUpType.shrink:
        return const Color(0xFFCE93D8);
      case PowerUpType.windCaller:
        return const Color(0xFF00E5FF);
      case PowerUpType.decoyClone:
        return const Color(0xFF9FA8DA);
      case PowerUpType.blackHole:
        return const Color(0xFF7C4DFF);
      case PowerUpType.turboDash:
        return const Color(0xFFFF3D00);
    }
  }

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
      case PowerUpType.doubleScore:
        return 'Double Score';
      case PowerUpType.shrink:
        return 'Shrink Fold';
      case PowerUpType.windCaller:
        return 'Wind Caller';
      case PowerUpType.decoyClone:
        return 'Decoy Clones';
      case PowerUpType.blackHole:
        return 'Black Hole';
      case PowerUpType.turboDash:
        return 'Turbo Dash';
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
      case PowerUpType.doubleScore:
        return 'double_score';
      case PowerUpType.shrink:
        return 'shrink';
      case PowerUpType.windCaller:
        return 'wind_caller';
      case PowerUpType.decoyClone:
        return 'decoy_clone';
      case PowerUpType.blackHole:
        return 'black_hole';
      case PowerUpType.turboDash:
        return 'turbo_dash';
    }
  }
}

/// Named synergy states created by stacking compatible active power-ups.
enum PowerUpCombo { phaseShield, goldVortex, timeDash }

/// High-risk variants collected directly from corrupted pickups. They are
/// intentionally separate from charge inventory: accepting the pickup starts
/// the bargain immediately.
enum CorruptedPowerUpType { cursedMagnet, unstableGhost }

extension CorruptedPowerUpInfo on CorruptedPowerUpType {
  String get displayName {
    switch (this) {
      case CorruptedPowerUpType.cursedMagnet:
        return 'Cursed Magnet';
      case CorruptedPowerUpType.unstableGhost:
        return 'Unstable Ghost';
    }
  }

  PowerUpType get baseType {
    switch (this) {
      case CorruptedPowerUpType.cursedMagnet:
        return PowerUpType.magnet;
      case CorruptedPowerUpType.unstableGhost:
        return PowerUpType.ghost;
    }
  }

  Color get color {
    switch (this) {
      case CorruptedPowerUpType.cursedMagnet:
        return const Color(0xFFE53935);
      case CorruptedPowerUpType.unstableGhost:
        return const Color(0xFF7C4DFF);
    }
  }
}

extension PowerUpComboInfo on PowerUpCombo {
  String get displayName {
    switch (this) {
      case PowerUpCombo.phaseShield:
        return 'Phase Shield';
      case PowerUpCombo.goldVortex:
        return 'Gold Vortex';
      case PowerUpCombo.timeDash:
        return 'Time Dash';
    }
  }

  Set<PowerUpType> get ingredients {
    switch (this) {
      case PowerUpCombo.phaseShield:
        return const {PowerUpType.shield, PowerUpType.ghost};
      case PowerUpCombo.goldVortex:
        return const {PowerUpType.magnet, PowerUpType.coinRush};
      case PowerUpCombo.timeDash:
        return const {PowerUpType.slowMo, PowerUpType.turboDash};
    }
  }

  Color get color {
    switch (this) {
      case PowerUpCombo.phaseShield:
        return const Color(0xFF80DEEA);
      case PowerUpCombo.goldVortex:
        return const Color(0xFFFFD740);
      case PowerUpCombo.timeDash:
        return const Color(0xFFB388FF);
    }
  }
}

Set<PowerUpCombo> powerUpCombosFor(Set<PowerUpType> activePowerUps) {
  return PowerUpCombo.values
      .where((combo) => activePowerUps.containsAll(combo.ingredients))
      .toSet();
}

// ── Plane Types ───────────────────────────────────────────────────────────────

enum PlaneType {
  dart,        // starter, balanced + distance bonus
  glider,      // wider turn radius, gentle drift — coin earner + thermals
  stuntFold,   // tighter turn radius, slightly higher fall speed — skill plane
  crane,       // origami crane — forgives tree branches
  stealthJet,  // stealth jet — tiny hitbox, fast dive recovery
  butterfly,   // origami butterfly — fall 0.75, auto-sway, extra thermal time
  bomber,      // paper bomber — slow, starts with 2 shield charges
  interceptor, // interceptor — turn 1.25, camera zoom out, no coin attract
  albatross,   // albatross — endless glide combo bonus
  biplane,     // classic biplane — dual wings, steady cruising
  ninjaStar,   // origami shuriken — ultra-snappy turns
  rocket,      // paper rocket — streamlined high-speed needle
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
      case PlaneType.butterfly:
        return 'Origami Butterfly';
      case PlaneType.bomber:
        return 'Paper Bomber';
      case PlaneType.interceptor:
        return 'Interceptor';
      case PlaneType.albatross:
        return 'Soaring Albatross';
      case PlaneType.biplane:
        return 'Classic Biplane';
      case PlaneType.ninjaStar:
        return 'Origami Shuriken';
      case PlaneType.rocket:
        return 'Paper Rocket';
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
      case PlaneType.butterfly:
        return 'butterfly';
      case PlaneType.bomber:
        return 'bomber';
      case PlaneType.interceptor:
        return 'interceptor';
      case PlaneType.albatross:
        return 'albatross';
      case PlaneType.biplane:
        return 'biplane';
      case PlaneType.ninjaStar:
        return 'ninja_star';
      case PlaneType.rocket:
        return 'rocket';
    }
  }

  /// One-line flavour for the hangar card.
  String get tagline {
    switch (this) {
      case PlaneType.dart:
        return 'Reliable starter — +15% distance score, fast ramp';
      case PlaneType.glider:
        return 'Floats longer — slow ramp, long-haul cruise';
      case PlaneType.stuntFold:
        return 'Snappy turns, 2× snap, +50% near-miss';
      case PlaneType.crane:
        return 'Graceful — 1 free tree branch brush-off';
      case PlaneType.stealthJet:
        return 'Slim hitbox (0.42), dives recover instantly';
      case PlaneType.butterfly:
        return 'Flutters gracefully — fall 0.75, auto-sway, +40% thermal';
      case PlaneType.bomber:
        return 'Heavy fortress — slow ramp, highest cruise cap';
      case PlaneType.interceptor:
        return 'Agile turn 1.25 — fastest speed ramp';
      case PlaneType.albatross:
        return 'Master glider — 2× streak, endless glide combo';
      case PlaneType.biplane:
        return 'Dual paper wings — rock-steady balance, smooth arcs';
      case PlaneType.ninjaStar:
        return 'Ultra-snappy turns, fast snap burst recharge';
      case PlaneType.rocket:
        return 'Fast-ramping dart with 1.10× cruise cap';
    }
  }

  /// Short trait bullets for hangar detail sheet.
  List<String> get traitBullets {
    switch (this) {
      case PlaneType.dart:
        return ['+15% distance score', 'Balanced handling', 'BOOST burst'];
      case PlaneType.glider:
        return [
          'Weak coin attract (95px @ 140px/s)',
          'Glide gravity 0.80',
          '1.2× thermal float',
        ];
      case PlaneType.stuntFold:
        return [
          'Turn 1.15 / Fall 1.10',
          '2× snap recharge',
          '+50% near-miss score',
        ];
      case PlaneType.crane:
        return [
          '1 free tree branch brush-off',
          'Turn 0.95 / Fall 0.88',
          'Forgives organic branches',
        ];
      case PlaneType.stealthJet:
        return [
          'Tiny hitbox (0.42)',
          'Dive gravity 0.88 recovery',
          'Wind control 1.08',
        ];
      case PlaneType.butterfly:
        return [
          'Floaty fall rate (0.75)',
          'Auto-sway + light, instant turns',
          '+40% thermal lift bonus',
        ];
      case PlaneType.bomber:
        return [
          'Starts with 2 shield charges',
          'Heavy frame — committed momentum turns',
          'Turn 0.80 / Fall 1.15',
        ];
      case PlaneType.interceptor:
        return [
          'High turn speed (1.25)',
          'Camera zooms out at speed',
          'No passive coin attraction',
        ];
      case PlaneType.albatross:
        return [
          'Endless glide combo, instant correction',
          '2× clean glide streak points',
          '50% slower combo decay in glide',
        ];
      case PlaneType.biplane:
        return [
          'Dual paper wings',
          'Balanced stability',
          'Extra coin magnet',
        ];
      case PlaneType.ninjaStar:
        return [
          'Ultra-snappy turns (1.25)',
          'Fast snap recharge',
          '+30% near-miss',
        ];
      case PlaneType.rocket:
        return [
          'High speed cruise (1.15)',
          'Needle hitbox (0.40), carries a bank',
          'Instant dive recovery',
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
      case PlaneType.butterfly:
        return 2000;
      case PlaneType.bomber:
        return 2500;
      case PlaneType.interceptor:
        return 3200;
      case PlaneType.albatross:
        return 3800;
      case PlaneType.biplane:
        return 2600;
      case PlaneType.ninjaStar:
        return 3500;
      case PlaneType.rocket:
        return 4200;
    }
  }

  /// Gem cost to unlock.
  int get unlockGemCost {
    switch (this) {
      case PlaneType.dart:
      case PlaneType.glider:
      case PlaneType.stuntFold:
      case PlaneType.crane:
      case PlaneType.butterfly:
      case PlaneType.albatross:
        return 0;
      case PlaneType.bomber:
        return 2;
      case PlaneType.stealthJet:
      case PlaneType.interceptor:
        return 5;
      case PlaneType.biplane:
        return 2;
      case PlaneType.ninjaStar:
        return 6;
      case PlaneType.rocket:
        return 10;
    }
  }

  /// Base turn speed multiplier.
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
        return 1.10; // responsive
      case PlaneType.butterfly:
        return 0.90; // soft flutter turns
      case PlaneType.bomber:
        return 0.80; // heavy deliberate turns
      case PlaneType.interceptor:
        return 1.25; // ultra agile
      case PlaneType.albatross:
        return 0.82; // wide sweeping turns
      case PlaneType.biplane:
        return 1.00; // steady cruiser
      case PlaneType.ninjaStar:
        return 1.25; // ultra snappy
      case PlaneType.rocket:
        return 1.15; // high response
    }
  }

  /// Distance-ramp multiplier for world speed (1.0 = baseline world-speed
  /// curve). Higher values reach cruising pace early; lower values reserve
  /// their strength for a longer, deliberate build.
  double get speedCurveMultiplier {
    switch (this) {
      case PlaneType.dart:
        return 1.20;
      case PlaneType.glider:
        return 0.72;
      case PlaneType.stuntFold:
        return 1.08;
      case PlaneType.crane:
        return 0.90;
      case PlaneType.stealthJet:
        return 1.12;
      case PlaneType.butterfly:
        return 0.82;
      case PlaneType.bomber:
        return 0.68;
      case PlaneType.interceptor:
        return 1.28;
      case PlaneType.albatross:
        return 0.78;
      case PlaneType.biplane:
        return 0.94;
      case PlaneType.ninjaStar:
        return 1.15;
      case PlaneType.rocket:
        return 1.17;
    }
  }

  /// Multiplier for the world-speed cap. Long-haul airframes intentionally
  /// trade a slow early ramp for a ceiling beyond the neutral 480 px/s cap.
  double get speedCapMultiplier {
    switch (this) {
      case PlaneType.dart:
        return 1.00;
      case PlaneType.glider:
        return 1.13;
      case PlaneType.stuntFold:
        return 1.00;
      case PlaneType.crane:
        return 1.04;
      case PlaneType.stealthJet:
        return 1.05;
      case PlaneType.butterfly:
        return 0.96;
      case PlaneType.bomber:
        return 1.16;
      case PlaneType.interceptor:
        return 1.04;
      case PlaneType.albatross:
        return 1.12;
      case PlaneType.biplane:
        return 1.06;
      case PlaneType.ninjaStar:
        return 1.00;
      case PlaneType.rocket:
        return 1.10;
    }
  }

  /// Human-readable speed behaviour for the hangar, where one SPD radar value
  /// cannot communicate both acceleration and a separate end-game cap.
  String get speedProfileLabel {
    switch (this) {
      case PlaneType.dart:
        return 'Fast ramp • standard cruise cap';
      case PlaneType.glider:
        return 'Slow ramp • 1.13× long-haul cap';
      case PlaneType.stuntFold:
        return 'Quick ramp • standard cruise cap';
      case PlaneType.crane:
        return 'Gentle ramp • 1.04× cruise cap';
      case PlaneType.stealthJet:
        return 'Fast ramp • 1.05× cruise cap';
      case PlaneType.butterfly:
        return 'Soft ramp • lower calm-sky cap';
      case PlaneType.bomber:
        return 'Slow ramp • 1.16× long-haul cap';
      case PlaneType.interceptor:
        return 'Very fast ramp • 1.04× cruise cap';
      case PlaneType.albatross:
        return 'Slow ramp • 1.12× long-haul cap';
      case PlaneType.biplane:
        return 'Steady ramp • 1.06× cruise cap';
      case PlaneType.ninjaStar:
        return 'Fast ramp • standard cruise cap';
      case PlaneType.rocket:
        return 'Fast ramp • 1.10× cruise cap';
    }
  }

  /// Relative wing loading (1.0 = the balanced Paper Dart).
  ///
  /// This is deliberately independent from [turnSpeedMultiplier]: turn speed
  /// describes how much authority a fold can generate, while wing loading
  /// describes how quickly it can change direction. The result is a light
  /// Butterfly or Albatross that reacts almost at once and a Bomber/Rocket
  /// that has to commit to a bank and carries that momentum through a turn.
  double get wingLoading {
    switch (this) {
      case PlaneType.dart:
        return 1.00;
      case PlaneType.glider:
        return 0.72;
      case PlaneType.stuntFold:
        return 0.88;
      case PlaneType.crane:
        return 0.78;
      case PlaneType.stealthJet:
        return 0.86;
      case PlaneType.butterfly:
        return 0.50;
      case PlaneType.bomber:
        return 1.85;
      case PlaneType.interceptor:
        return 0.68;
      case PlaneType.albatross:
        return 0.58;
      case PlaneType.biplane:
        return 1.05;
      case PlaneType.ninjaStar:
        return 0.52;
      case PlaneType.rocket:
        return 1.52;
    }
  }

  /// Base fall speed multiplier.
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
        return 1.05; // recovers quickly
      case PlaneType.butterfly:
        return 0.75; // floaty butterfly fall
      case PlaneType.bomber:
        return 1.15; // heavy payload fall
      case PlaneType.interceptor:
        return 1.10; // streamlined dive
      case PlaneType.albatross:
        return 0.82; // dynamic soaring
      case PlaneType.biplane:
        return 0.95; // steady cruiser
      case PlaneType.ninjaStar:
        return 1.12; // quick drop
      case PlaneType.rocket:
        return 1.18; // fast dive
    }
  }

  /// Per-plane hitbox scale override (null -> use global default 0.55).
  double? get hitboxScaleOverride {
    switch (this) {
      case PlaneType.stealthJet:
        return GameConfig.stealthHitboxScale; // 0.42
      case PlaneType.rocket:
        return 0.40;
      case PlaneType.interceptor:
        return 0.44;
      default:
        return null;
    }
  }
}

/// Upgrade tree definitions per plane across 3 levels.
extension PlaneUpgradeInfo on PlaneType {
  /// Coin cost to upgrade to [toLevel] (2 or 3).
  int upgradeCost(int toLevel) {
    if (toLevel == 2) {
      switch (this) {
        case PlaneType.dart:
          return 600;
        case PlaneType.glider:
          return 750;
        case PlaneType.stuntFold:
          return 900;
        case PlaneType.crane:
          return 1000;
        case PlaneType.stealthJet:
          return 1200;
        case PlaneType.butterfly:
          return 850;
        case PlaneType.bomber:
          return 950;
        case PlaneType.interceptor:
          return 1100;
        case PlaneType.albatross:
          return 1000;
        case PlaneType.biplane:
          return 800;
        case PlaneType.ninjaStar:
          return 1100;
        case PlaneType.rocket:
          return 1300;
      }
    } else if (toLevel == 3) {
      switch (this) {
        case PlaneType.dart:
          return 1400;
        case PlaneType.glider:
          return 1750;
        case PlaneType.stuntFold:
          return 2000;
        case PlaneType.crane:
          return 2200;
        case PlaneType.stealthJet:
          return 2500;
        case PlaneType.butterfly:
          return 1900;
        case PlaneType.bomber:
          return 2100;
        case PlaneType.interceptor:
          return 2400;
        case PlaneType.albatross:
          return 2200;
        case PlaneType.biplane:
          return 1800;
        case PlaneType.ninjaStar:
          return 2300;
        case PlaneType.rocket:
          return 2600;
      }
    }
    return 0;
  }

  /// Short description of the perk unlocked at [level] (1..3).
  String perkForLevel(int level) {
    switch (this) {
      case PlaneType.dart:
        switch (level) {
          case 1:
            return '+15% distance score';
          case 2:
            return '+20% distance score & +5% turn speed';
          case 3:
          default:
            return '+25% distance score & +15% BOOST impulse';
        }
      case PlaneType.glider:
        switch (level) {
          case 1:
            return '95px coin attract @ 140px/s, 1.2× thermal float';
          case 2:
            return '125px coin attract @ 180px/s, 1.35× thermal float';
          case 3:
          default:
            return '160px coin attract @ 220px/s, 1.5× thermal float';
        }
      case PlaneType.stuntFold:
        switch (level) {
          case 1:
            return '2× snap recharge, +50% near-miss score';
          case 2:
            return '2.5× snap recharge, +75% near-miss score';
          case 3:
          default:
            return '3× snap recharge, +100% near-miss & 3rd snap slot';
        }
      case PlaneType.crane:
        switch (level) {
          case 1:
            return '1 free tree branch brush-off / run';
          case 2:
            return '1 brush-off, +15% glide duration, softer recovery';
          case 3:
          default:
            return '2 free tree branch brush-offs / run';
        }
      case PlaneType.stealthJet:
        switch (level) {
          case 1:
            return '0.42 hitbox scale, 0.88 dive recovery, 1.08 wind control';
          case 2:
            return '0.40 hitbox scale, 0.82 dive recovery, 1.15 wind control';
          case 3:
          default:
            return '0.38 ultra-slim hitbox, instant dive recovery';
        }
      case PlaneType.butterfly:
        switch (level) {
          case 1:
            return '0.75 fall speed, auto-sway, +40% thermal lift';
          case 2:
            return '0.72 fall speed, +50% thermal lift, +15% sway weave';
          case 3:
          default:
            return '0.68 ultra-float fall, +65% thermal lift bonus';
        }
      case PlaneType.bomber:
        switch (level) {
          case 1:
            return 'Spawns with 2 shield charges every run';
          case 2:
            return '2 shield charges, +10% turn speed & blast recovery';
          case 3:
          default:
            return 'Spawns with 3 fortified shield charges / run';
        }
      case PlaneType.interceptor:
        switch (level) {
          case 1:
            return '1.25 turn speed, camera zoom-out, 0 coin attract';
          case 2:
            return '1.30 turn speed, faster snap recharge';
          case 3:
          default:
            return '1.35 ultra-agility, +20% high-speed distance score';
        }
      case PlaneType.albatross:
        switch (level) {
          case 1:
            return '2× glide streak points, 50% slower combo decay in glide';
          case 2:
            return '2.5× glide streak points, 60% slower combo decay';
          case 3:
          default:
            return '3× glide streak points, 75% slower combo decay in glide';
        }
      case PlaneType.biplane:
        switch (level) {
          case 1:
            return 'Dual paper wings, steady cruise, +10% coin magnet';
          case 2:
            return 'Turn 1.05, +20% coin magnet, +10% glide float';
          case 3:
          default:
            return 'Turn 1.10, starts with 1 free shield every run';
        }
      case PlaneType.ninjaStar:
        switch (level) {
          case 1:
            return '1.25 turn agility, fast snap recharge, +30% near-miss';
          case 2:
            return '1.30 turn agility, 2.5× snap recharge, +45% near-miss';
          case 3:
          default:
            return '1.35 ultra-agility, 3× snap recharge, +60% near-miss';
        }
      case PlaneType.rocket:
        switch (level) {
          case 1:
            return '1.15 speed, 0.40 needle hitbox, instant dive recovery';
          case 2:
            return '1.20 speed, 0.38 hitbox, +15% distance score';
          case 3:
          default:
            return '1.25 speed, 0.36 hitbox, +25% distance score, super boost';
        }
    }
  }

  /// Turn speed multiplier scaled by upgrade [level] (1..3).
  double turnSpeedForLevel(int level) {
    final base = turnSpeedMultiplier;
    switch (level) {
      case 2:
        return base * 1.05;
      case 3:
        return base * 1.10;
      case 1:
      default:
        return base;
    }
  }

  /// Fall speed multiplier scaled by upgrade [level] (1..3).
  double fallSpeedForLevel(int level) {
    final base = fallSpeedMultiplier;
    switch (level) {
      case 2:
        return base * 0.96;
      case 3:
        return base * 0.92;
      case 1:
      default:
        return base;
    }
  }

  /// Hitbox scale override scaled by upgrade [level] (1..3).
  double? hitboxScaleForLevel(int level) {
    final base = hitboxScaleOverride;
    if (base == null) return null;
    switch (level) {
      case 2:
        return (base - 0.02).clamp(0.35, 0.55);
      case 3:
        return (base - 0.04).clamp(0.35, 0.55);
      case 1:
      default:
        return base;
    }
  }
}

/// Signature power-up each plane carries.
extension PlanePowerUp on PlaneType {
  /// True when this plane's signature action is the paper-snap BOOST burst.
  bool get usesBoostAsSignatureAction =>
      this == PlaneType.dart ||
      this == PlaneType.crane ||
      this == PlaneType.rocket;

  /// The timed power-up this plane carries.
  PowerUpType get signaturePowerUp {
    switch (this) {
      case PlaneType.dart:
      case PlaneType.crane:
      case PlaneType.rocket:
        return PowerUpType.magnet;
      case PlaneType.glider:
      case PlaneType.albatross:
        return PowerUpType.magnet;
      case PlaneType.stuntFold:
      case PlaneType.ninjaStar:
        return PowerUpType.ghost;
      case PlaneType.stealthJet:
      case PlaneType.interceptor:
        return PowerUpType.slowMo;
      case PlaneType.butterfly:
        return PowerUpType.coinRush;
      case PlaneType.bomber:
      case PlaneType.biplane:
        return PowerUpType.shield;
    }
  }

  /// Ability summary for tooltips.
  String get signatureActionLabel {
    if (usesBoostAsSignatureAction) return 'BOOST burst';
    return signaturePowerUp.displayName;
  }
}

// ── Paper Skins ───────────────────────────────────────────────────────────────

/// Collectibility treatment for paper skins in the Hangar and Shop.
enum SkinRarity { common, rare, epic, legendary, mythic }

extension SkinRarityInfo on SkinRarity {
  String get label {
    switch (this) {
      case SkinRarity.common:
        return 'COMMON';
      case SkinRarity.rare:
        return 'RARE';
      case SkinRarity.epic:
        return 'EPIC';
      case SkinRarity.legendary:
        return 'LEGENDARY';
      case SkinRarity.mythic:
        return 'MYTHIC';
    }
  }

  Color get color {
    switch (this) {
      case SkinRarity.common:
        return const Color(0xFF90A4AE);
      case SkinRarity.rare:
        return const Color(0xFF42A5F5);
      case SkinRarity.epic:
        return const Color(0xFFAB47BC);
      case SkinRarity.legendary:
        return const Color(0xFFFFB300);
      case SkinRarity.mythic:
        // Mythic uses a moving rainbow frame; this is its fallback badge tint.
        return const Color(0xFFFF80AB);
    }
  }
}

/// Named limited-time rotations used by seasonal PaperSkin metadata.
enum SeasonalRotation { halloween, winter, lunarNewYear }

/// Calendar window for a limited-time paper skin. Windows use the device's
/// local calendar, which keeps the Shop countdown intuitive in every region.
class SeasonalAvailability {
  const SeasonalAvailability({
    required this.rotation,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
  });

  final SeasonalRotation rotation;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  String get displayName {
    switch (rotation) {
      case SeasonalRotation.halloween:
        return 'Halloween Flight';
      case SeasonalRotation.winter:
        return 'Winter Flight';
      case SeasonalRotation.lunarNewYear:
        return 'Lunar New Year';
    }
  }

  String get icon {
    switch (rotation) {
      case SeasonalRotation.halloween:
        return '🎃';
      case SeasonalRotation.winter:
        return '❄️';
      case SeasonalRotation.lunarNewYear:
        return '🏮';
    }
  }

  bool get _crossesYear =>
      startMonth > endMonth ||
      (startMonth == endMonth && startDay > endDay);

  bool isAvailableOn(DateTime now) {
    final startThisYear = DateTime(now.year, startMonth, startDay);
    if (!_crossesYear) {
      return !now.isBefore(startThisYear) &&
          !now.isAfter(_endForYear(now.year));
    }

    if (!now.isBefore(startThisYear)) {
      return !now.isAfter(_endForYear(now.year + 1));
    }
    return !now.isBefore(DateTime(now.year - 1, startMonth, startDay)) &&
        !now.isAfter(_endForYear(now.year));
  }

  DateTime? activeEndsAt(DateTime now) {
    if (!isAvailableOn(now)) return null;
    final startThisYear = DateTime(now.year, startMonth, startDay);
    return !_crossesYear || now.isBefore(startThisYear)
        ? _endForYear(now.year)
        : _endForYear(now.year + 1);
  }

  DateTime nextStartsAt(DateTime now) {
    final startThisYear = DateTime(now.year, startMonth, startDay);
    return now.isBefore(startThisYear)
        ? startThisYear
        : DateTime(now.year + 1, startMonth, startDay);
  }

  DateTime _endForYear(int year) =>
      DateTime(year, endMonth, endDay, 23, 59, 59, 999);
}

enum PaperSkin {
  plain,            // default white / gold
  newspaper,        // newspaper print with lorem squiggles
  graphPaper,       // light blue grid & drafting coordinates
  notebookDoodle,   // ruled paper + doodles & margins
  holographicFoil,  // iridescent foil with diagonal sweep
  watercolorWash,   // soft pastel watercolor wash with dynamic bleed
  goldLeaf,         // metallic gold with sparkling TTL flecks & rim glow
  blueprint,        // technical CAD blueprint line art
  receipt,          // ticket stub with perforated edge & barcode
  carbonFiber,      // dark carbon fiber weave twill
  mangaHalftone,    // manga comic screentone halftone dots & speedlines
  kraftEnvelope,    // kraft envelope with airmail border & postal stamp
  prideGradient,    // animated pride spectrum rainbow wave
  dragonScales,     // origami dragon emerald/ruby faceted scale pattern
  snowflake,        // winter seasonal icy snowflake crystal paper
  pumpkin,          // autumn seasonal harvest pumpkin paper with leaf stamps
  cherryBlossom,    // spring seasonal sakura blossom paper with falling petals
  lavaLamp,         // animated glowing neon liquid magma blobs
  animatedHologram, // premium animated 360° hue-rotating holographic prism
  customCraft,      // player custom dual-tone craft paper with pattern stamps
  flipbook,         // premium 8-frame hand-flipped paper animation
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
      case PaperSkin.blueprint:
        return 'Blueprint CAD';
      case PaperSkin.receipt:
        return 'Receipt Stub';
      case PaperSkin.carbonFiber:
        return 'Carbon Fiber';
      case PaperSkin.mangaHalftone:
        return 'Manga Halftone';
      case PaperSkin.kraftEnvelope:
        return 'Kraft Envelope';
      case PaperSkin.prideGradient:
        return 'Pride Spectrum';
      case PaperSkin.dragonScales:
        return 'Dragon Scales';
      case PaperSkin.snowflake:
        return 'Winter Snowflake';
      case PaperSkin.pumpkin:
        return 'Harvest Pumpkin';
      case PaperSkin.cherryBlossom:
        return 'Cherry Blossom';
      case PaperSkin.lavaLamp:
        return 'Lava Lamp';
      case PaperSkin.animatedHologram:
        return 'Prism Hologram';
      case PaperSkin.customCraft:
        return 'Custom Craft';
      case PaperSkin.flipbook:
        return 'Flipbook Flight';
    }
  }

  String get description {
    switch (this) {
      case PaperSkin.plain:
        return 'Classic white — clean and crisp';
      case PaperSkin.newspaper:
        return 'Vintage newsprint with headlines & columns';
      case PaperSkin.graphPaper:
        return 'Engineer\'s blue technical drafting grid';
      case PaperSkin.notebookDoodle:
        return 'Ruled lines, margin rule + hand-drawn star';
      case PaperSkin.holographicFoil:
        return 'Moving diagonal iridescent rainbow shimmer';
      case PaperSkin.watercolorWash:
        return 'Soft pastel watercolor wash with dynamic bleed';
      case PaperSkin.goldLeaf:
        return 'Luxurious gold leaf with sparkling flecks';
      case PaperSkin.blueprint:
        return 'Technical blue CAD schematic & compass line art';
      case PaperSkin.receipt:
        return 'Perforated register ticket stub with barcode';
      case PaperSkin.carbonFiber:
        return 'Woven dark carbon twill with specular weave';
      case PaperSkin.mangaHalftone:
        return 'Manga comic screen-tone dots & speedlines';
      case PaperSkin.kraftEnvelope:
        return 'Natural kraft paper with airmail chevrons & stamp';
      case PaperSkin.prideGradient:
        return 'Animated rainbow pride spectrum wave';
      case PaperSkin.dragonScales:
        return 'Lunar New Year dragon scales with lantern-gold embers';
      case PaperSkin.snowflake:
        return 'Winter rotation crystalline snowflake paper';
      case PaperSkin.pumpkin:
        return 'Halloween rotation pumpkin paper with drifting leaves';
      case PaperSkin.cherryBlossom:
        return 'Spring seasonal sakura petals & blossom twig';
      case PaperSkin.lavaLamp:
        return 'Animated hypnotic glowing neon liquid magma blobs';
      case PaperSkin.animatedHologram:
        return 'Premium 360° hue-rotating rainbow prism foil';
      case PaperSkin.customCraft:
        return 'Player custom dual-tone craft paper + pattern stamps';
      case PaperSkin.flipbook:
        return 'Eight hand-flipped prism frames with a paper-thin motion trail';
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
      case PaperSkin.receipt:
        return 800;
      case PaperSkin.customCraft:
        return 1000;
      case PaperSkin.kraftEnvelope:
        return 1100;
      case PaperSkin.watercolorWash:
        return 1200;
      case PaperSkin.snowflake:
      case PaperSkin.pumpkin:
        return 1300;
      case PaperSkin.blueprint:
        return 1400;
      case PaperSkin.mangaHalftone:
        return 1500;
      case PaperSkin.prideGradient:
        return 1600;
      case PaperSkin.cherryBlossom:
        return 1700;
      case PaperSkin.carbonFiber:
        return 1800;
      case PaperSkin.holographicFoil:
        return 2000;
      case PaperSkin.dragonScales:
        return 2400;
      case PaperSkin.lavaLamp:
        return 2800;
      case PaperSkin.goldLeaf:
        return 3000;
      case PaperSkin.animatedHologram:
        return 3200;
      case PaperSkin.flipbook:
        return 3600;
    }
  }

  int get unlockCostGems {
    switch (this) {
      case PaperSkin.plain:
      case PaperSkin.newspaper:
      case PaperSkin.graphPaper:
      case PaperSkin.notebookDoodle:
      case PaperSkin.receipt:
      case PaperSkin.customCraft:
      case PaperSkin.kraftEnvelope:
      case PaperSkin.watercolorWash:
      case PaperSkin.snowflake:
      case PaperSkin.pumpkin:
      case PaperSkin.blueprint:
      case PaperSkin.mangaHalftone:
      case PaperSkin.prideGradient:
      case PaperSkin.cherryBlossom:
        return 0;
      case PaperSkin.carbonFiber:
        return 2;
      case PaperSkin.holographicFoil:
        return 3;
      case PaperSkin.dragonScales:
        return 4;
      case PaperSkin.lavaLamp:
        return 5;
      case PaperSkin.goldLeaf:
        return 8;
      case PaperSkin.animatedHologram:
        return 8;
      case PaperSkin.flipbook:
        return 10;
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
      case PaperSkin.blueprint:
        return 0xFF0D47A1;
      case PaperSkin.receipt:
        return 0xFFF5F5F0;
      case PaperSkin.carbonFiber:
        return 0xFF212121;
      case PaperSkin.mangaHalftone:
        return 0xFFFAFAFA;
      case PaperSkin.kraftEnvelope:
        return 0xFFD7CCC8;
      case PaperSkin.prideGradient:
        return 0xFFFF80AB;
      case PaperSkin.dragonScales:
        return 0xFF2E7D32;
      case PaperSkin.snowflake:
        return 0xFFE1F5FE;
      case PaperSkin.pumpkin:
        return 0xFFE65100;
      case PaperSkin.cherryBlossom:
        return 0xFFFCE4EC;
      case PaperSkin.lavaLamp:
        return 0xFF4A148C;
      case PaperSkin.animatedHologram:
        return 0xFFE040FB;
      case PaperSkin.customCraft:
        return 0xFF4FC3F7;
      case PaperSkin.flipbook:
        return 0xFF7C4DFF;
    }
  }

  /// Rarity tier drives Hangar/list presentation only; all unlocked skins
  /// remain cosmetic and do not alter gameplay unless a configured synergy
  /// explicitly applies.
  SkinRarity get rarity {
    switch (this) {
      case PaperSkin.plain:
      case PaperSkin.newspaper:
      case PaperSkin.graphPaper:
      case PaperSkin.notebookDoodle:
      case PaperSkin.receipt:
      case PaperSkin.kraftEnvelope:
      case PaperSkin.customCraft:
        return SkinRarity.common;
      case PaperSkin.watercolorWash:
      case PaperSkin.blueprint:
      case PaperSkin.snowflake:
      case PaperSkin.pumpkin:
      case PaperSkin.cherryBlossom:
        return SkinRarity.rare;
      case PaperSkin.carbonFiber:
      case PaperSkin.mangaHalftone:
      case PaperSkin.prideGradient:
      case PaperSkin.holographicFoil:
        return SkinRarity.epic;
      case PaperSkin.dragonScales:
      case PaperSkin.lavaLamp:
      case PaperSkin.goldLeaf:
        return SkinRarity.legendary;
      case PaperSkin.animatedHologram:
      case PaperSkin.flipbook:
        return SkinRarity.mythic;
    }
  }

  /// True when this skin renders an eight-frame SpriteAnimationComponent
  /// overlay instead of a single procedural Canvas pass.
  bool get usesFrameAnimation =>
      this == PaperSkin.animatedHologram ||
      this == PaperSkin.lavaLamp ||
      this == PaperSkin.flipbook;

  int get animationFrameCount => usesFrameAnimation ? 8 : 0;

  /// Null for evergreen skins. Seasonal skins remain usable after unlock, but
  /// can only be newly purchased during this calendar window.
  SeasonalAvailability? get seasonalAvailability {
    switch (this) {
      case PaperSkin.pumpkin:
        return const SeasonalAvailability(
          rotation: SeasonalRotation.halloween,
          startMonth: 10,
          startDay: 15,
          endMonth: 11,
          endDay: 5,
        );
      case PaperSkin.snowflake:
        return const SeasonalAvailability(
          rotation: SeasonalRotation.winter,
          startMonth: 12,
          startDay: 1,
          endMonth: 1,
          endDay: 10,
        );
      case PaperSkin.dragonScales:
        return const SeasonalAvailability(
          rotation: SeasonalRotation.lunarNewYear,
          startMonth: 1,
          startDay: 20,
          endMonth: 2,
          endDay: 20,
        );
      default:
        return null;
    }
  }

  bool isAvailableForPurchaseAt(DateTime now) =>
      seasonalAvailability?.isAvailableOn(now) ?? true;
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

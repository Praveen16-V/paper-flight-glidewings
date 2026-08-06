/// All enums for Paper Flight — kept in one file for easy cross-reference.

// ── Game State ──────────────────────────────────────────────────────────────

enum GamePhase {
  idle,      // before run starts
  playing,   // active run
  paused,    // tapped pause
  dying,     // crash freeze frame
  gameOver,  // transition to results screen
  reviving,  // watching rewarded ad to revive
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
  dart,      // starter, balanced
  glider,    // wider turn radius, gentle drift — coin earner
  stuntFold, // tighter turn radius, slightly higher fall speed — skill plane
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
    }
  }
}

// ── Wind ─────────────────────────────────────────────────────────────────────

enum WindType {
  calm,
  leftPush,
  rightPush,
  turbulent,
  thermal, // updraft
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

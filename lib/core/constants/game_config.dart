/// Central tuning knobs for all gameplay systems.
/// Adjust here — never hard-code magic numbers in components.
abstract class GameConfig {
  // ── Viewport ─────────────────────────────────────────────────────────────
  /// Design resolution width (logical pixels). Flame scales to device.
  static const double designWidth = 390.0;
  static const double designHeight = 844.0;

  // ── Scroll / Speed ───────────────────────────────────────────────────────
  /// Starting world scroll speed in logical px/s (downward).
  static const double baseScrollSpeed = 220.0;

  /// Maximum scroll speed cap — prevents unplayable frame windows.
  static const double maxScrollSpeed = 650.0;

  /// Speed added per second of elapsed run time.
  static const double scrollAcceleration = 3.5;

  /// Speed multiplier applied during Turbo Gust power-up.
  static const double turboPowerUpMultiplier = 1.6;

  /// Speed multiplier during Slow-Mo power-up.
  static const double slowMoPowerUpMultiplier = 0.45;

  // ── Plane Physics ────────────────────────────────────────────────────────
  /// Upward screen velocity (px/s) while holding.
  static const double liftForce = 310.0;

  /// Downward gravity force (px/s²). Kept gentle so releasing a hold curves
  /// into a glide instead of dropping the plane abruptly.
  static const double gravity = 320.0;

  /// Maximum downward fall speed.
  static const double maxFallSpeed = 500.0;

  /// Horizontal tilt max speed (px/s at full tilt). A modest cap makes a
  /// full phone tilt feel like a controlled bank rather than a sideways jump.
  static const double maxTiltSpeed = 175.0;

  /// Low-pass filter coefficient for tilt smoothing (0 = no smoothing, 1 = frozen).
  /// This is deliberately small: sensor samples ease into the steering target.
  static const double tiltLowPassAlpha = 0.10;

  /// Per-frame blend used when the plane follows its filtered tilt target.
  /// Keeping this below the input filter removes sudden lateral direction changes.
  static const double tiltVelocityResponse = 0.07;

  /// Default tilt sensitivity (1.0 = neutral, range 0.3–2.0 via settings).
  static const double defaultTiltSensitivity = 1.0;

  /// Horizontal margin — plane cannot go beyond this from screen edge.
  static const double horizontalEdgeMargin = 24.0;

  /// Plane starts at this fractional Y on screen (0 = top, 1 = bottom).
  static const double planeStartY = 0.65;

  /// Plane starts at horizontal center.
  static const double planeStartX = 0.5;

  /// Plane collision box as fraction of sprite size.
  static const double planeHitboxScale = 0.55;

  // ── Enhanced Flight Physics ───────────────────────────────────────────────
  // Feel target: hold eases into a gentle climb; release keeps that momentum
  // and curves naturally into a glide. Neither transition changes velocity on
  // a single frame.

  /// Maximum upward velocity (px/s, negative = up) allowed for a snap burst.
  /// Normal holds do not set this directly.
  static const double liftSnapKick = -185.0;

  /// Gentle terminal climb speed (px/s, negative = up) while holding.
  static const double liftCruiseSpeed = -135.0;

  /// Rate for easing the current vertical velocity toward the hold target.
  static const double liftKickDecayRate = 2.4;

  /// Retained for tuning compatibility. Release now preserves velocity fully,
  /// avoiding the visible speed change that occurred at finger-up.
  static const double glideArcPreservation = 1.0;

  /// Gravity multiplier during the glide arc phase (lighter than full gravity).
  /// Gives the "coast" feel before the natural dive takes over.
  static const double glideGravityScale = 0.62;

  /// Gravity multiplier once the glide arc is exhausted (normal fall).
  static const double fullGravityScale = 1.0;

  /// Sinusoidal bob amplitude added to vertical velocity (px/s).
  /// Gives the natural undulation of a paper plane riding air.
  /// ±22 px/s is subtle and perceptible but not distracting.
  static const double oscillationAmplitude = 22.0;

  /// Oscillation frequency in cycles per second (Hz).
  static const double oscillationFrequency = 1.1;

  /// Rate at which oscillation ramps up after release (strength units/s).
  /// Prevents a jarring jump to full oscillation immediately on release.
  static const double oscillationFadeInRate = 2.5;

  /// Nose-up pitch bias (radians) added while glide arc is active and
  /// the plane is still moving upward — gives that "float" moment.
  static const double glideNoseUpBias = 0.09;

  // ── Wing Squish Effect ────────────────────────────────────────────────────

  /// Scale Y at peak squish when hold is pressed (< 1.0 = compressed).
  static const double wingSquishScaleY = 0.82;

  /// Total duration (seconds) of the squish-in + spring-back cycle.
  static const double wingSquishDuration = 0.12;

  // ── Plane Trail ───────────────────────────────────────────────────────────

  /// Number of position samples kept in the trail history.
  static const int trailLength = 18;

  /// Seconds between trail position samples.
  static const double trailSampleInterval = 0.030;

  /// Maximum alpha of the trail at its head (0.0–1.0).
  static const double trailHeadAlpha = 0.38;

  /// Stroke width at the trail head (px).
  static const double trailHeadWidth = 2.6;

  /// Stroke width at the trail tail (px).
  static const double trailTailWidth = 0.5;

  // ── Wind ────────────────────────────────────────────────────────────────
  /// Number of wind column lanes across screen width.
  static const int windLaneCount = 4;

  /// Max lateral wind push force (px/s).
  static const double maxWindForce = 90.0;

  /// Thermal (updraft) lift force (px/s) when plane is in thermal lane.
  static const double thermalLiftForce = 160.0;

  /// Noise time scale — controls how fast wind patterns evolve.
  static const double windNoiseTimeScale = 0.4;

  /// Noise space scale per lane.
  static const double windNoiseLaneScale = 1.2;

  /// Turbulence pocket control reduction (0–1, fraction of input ignored).
  static const double turbulenceControlReduction = 0.35;

  // ── Obstacles ────────────────────────────────────────────────────────────
  /// Minimum vertical gap between spawned obstacles (px).
  static const double obstacleMinGap = 140.0;

  /// Y position just above viewport where obstacles spawn.
  static const double obstacleSpawnY = -80.0;

  /// Y position below viewport where obstacles are recycled.
  static const double obstacleRecycleY = 920.0;

  /// Starting spawn interval in seconds (decreases with speed).
  static const double obstacleBaseSpawnInterval = 1.8;

  /// Minimum spawn interval floor.
  static const double obstacleMinSpawnInterval = 0.55;

  /// Upper-third Y threshold (fraction) for hazard density bias.
  static const double upperHazardBiasThreshold = 0.33;

  // ── Coins ────────────────────────────────────────────────────────────────
  static const double coinSpawnY = -40.0;
  static const double coinRecycleY = 920.0;
  static const double coinBaseSpawnInterval = 0.9;
  static const double coinMagnetRadius = 130.0;
  static const int coinComboResetOnHit = 0; // combo resets to 0 on obstacle hit
  static const double coinSize = 28.0;

  // ── Near-Miss ────────────────────────────────────────────────────────────
  /// How close to an obstacle (px) counts as a near-miss.
  static const double nearMissDistance = 32.0;

  /// Near-miss points awarded per event.
  static const int nearMissPoints = 25;

  // ── Scoring ──────────────────────────────────────────────────────────────
  /// Score per meter of distance.
  static const double scorePerMeter = 1.0;

  /// Score multiplier per coin in active combo (stacks up to comboMax).
  static const double comboMultiplierStep = 0.1;
  static const int comboMax = 20;

  // ── Power-ups ────────────────────────────────────────────────────────────
  static const double powerUpSpawnY = -50.0;
  static const double powerUpRecycleY = 920.0;
  static const double powerUpBaseSpawnInterval = 8.0;
  static const double shieldDuration = 0.0; // absorbs 1 hit, no time limit
  static const double magnetDuration = 6.0; // seconds
  static const double turboDuration = 5.0;
  static const double slowMoDuration = 4.0;

  // ── Monetization / Ad Timing ──────────────────────────────────────────────
  /// Minimum runs before first interstitial is ever shown.
  static const int interstitialHoneymoonRuns = 3;

  /// Show interstitial at most once per N runs.
  static const int interstitialFrequencyCap = 3;

  // ── Biome Distance Thresholds (meters) ────────────────────────────────────
  static const double biomeBackyardEnd = 300.0;
  static const double biomeCityEnd = 800.0;
  static const double biomeStormEnd = 1500.0;
  static const double biomeMountainEnd = 2500.0;
  static const double biomeNightEnd = 4000.0;
  // Edge of Atmosphere = beyond 4000 m, endgame loop

  // ── UI Animation ─────────────────────────────────────────────────────────
  static const Duration screenTransition = Duration(milliseconds: 300);
  static const Duration crashSlowMoFreeze = Duration(milliseconds: 120);
}

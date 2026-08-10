/// Central tuning knobs for all gameplay systems.
/// Adjust here — never hard-code magic numbers in components.
abstract class GameConfig {
  /// Stable identifier attached to gameplay, economy, ad, and performance
  /// telemetry. Increment this whenever a tuning cohort changes so dashboards
  /// never compare unlike balance curves as if they were one population.
  static const String balanceVersion = '2026.08-flight-4';

  /// Riverpod/HUD publishing cadence. The Flame loop still simulates every
  /// frame; Flutter widgets receive a compact snapshot at 10 Hz instead of
  /// rebuilding at device refresh rate.
  static const double hudUpdateIntervalSeconds = 0.1;

  /// Live settings/equipment are sampled outside the per-frame hot path.
  static const double runtimeStateSyncIntervalSeconds = 0.5;

  // ── Viewport ─────────────────────────────────────────────────────────────
  /// Design resolution width (logical pixels). Flame scales to device.
  static const double designWidth = 390.0;
  static const double designHeight = 844.0;

  // ── Scroll / Speed ───────────────────────────────────────────────────────
  /// Starting world scroll speed in logical px/s (downward). Intentionally very
  /// low so the world is almost still at the start — it only begins to move
  /// past the plane as distance accumulates (see [scrollSpeedPerMeter]).
  static const double baseScrollSpeed = 80.0;

  /// Neutral-airframe scroll-speed cap. Long-haul airframes may scale this via
  /// their own cap multiplier while still using it as the balance base.
  static const double maxScrollSpeed = 480.0;

  /// Scroll speed gained (px/s) per meter the player has traveled.
  ///
  /// Speed is a pure function of distance reached, not of elapsed time — so the
  /// world only speeds up as you fly further, ramping in gradually and smoothly.
  /// (baseline: base + 0.16 × meters, capped around 2500 m; individual
  /// airframes adjust the ramp/cap through their speed-curve data.)
  static const double scrollSpeedPerMeter = 0.16;

  /// Evaluates a distance-based world-speed curve for a specific airframe.
  /// [curveMultiplier] changes how quickly the world accelerates; [capMultiplier]
  /// permits slow-ramping long-haul folds to eventually exceed the neutral cap.
  /// Keeping this pure makes balance comparisons deterministic and testable.
  static double curvedScrollSpeedForDistance({
    required double meters,
    required double baseSpeed,
    required double speedPerMeter,
    required double maxSpeed,
    required double curveMultiplier,
    required double capMultiplier,
  }) {
    final safeMeters = meters < 0 ? 0.0 : meters;
    final multipliedCap = maxSpeed * capMultiplier;
    final cap = multipliedCap < baseSpeed ? baseSpeed : multipliedCap;
    final speed = baseSpeed + speedPerMeter * curveMultiplier * safeMeters;
    return speed.clamp(baseSpeed, cap).toDouble();
  }

  /// Distance (meters) at which dynamic obstacles (birds, kites, balloons,
  /// drones) begin to gain any lateral movement. Below this they scroll
  /// straight down with the world — effectively static, as requested.
  static const double dynamicObstacleRampStartMeters = 0.0;

  /// Distance (meters) by which dynamic obstacles reach their full lateral
  /// movement amplitude. Between [dynamicObstacleRampStartMeters] and this
  /// value the drift / tracking eases in linearly with distance flown.
  static const double dynamicObstacleRampEndMeters = 350.0;

  /// Speed multiplier during Slow-Mo power-up.
  static const double slowMoPowerUpMultiplier = 0.45;

  // ── Plane Physics ────────────────────────────────────────────────────────
  /// Upward screen velocity (px/s) while holding.
  static const double liftForce = 310.0;

  /// Downward gravity force (px/s²). A paper plane has almost no weight, so
  /// gravity is kept very gentle — releasing a hold curves into a long, floaty
  /// glide instead of dropping the plane abruptly.
  static const double gravity = 150.0;

  /// Maximum downward fall speed. Low so the plane drifts like paper rather
  /// than plunging like an aircraft.
  static const double maxFallSpeed = 250.0;

  /// Horizontal tilt max speed (px/s at full tilt). A low cap makes a full
  /// phone tilt feel like a controlled, unhurried bank — not a sideways jump.
  static const double maxTiltSpeed = 135.0;

  /// Low-pass filter coefficient for tilt smoothing (0 = no smoothing, 1 = frozen).
  /// This is deliberately small: sensor samples ease into the steering target.
  static const double tiltLowPassAlpha = 0.10;

  // ── Dynamic Wing Loading / Turn Momentum ─────────────────────────────────
  /// Neutral (wing-loading 1.0) lateral response in inverse seconds. The
  /// response is converted to a frame-rate-independent exponential blend by
  /// [InputManager]. Lower wing loading responds much faster; high loading
  /// retains a deliberate, weighty turn arc.
  static const double turnMomentumResponsePerSecond = 7.5;

  /// Exponent applied to a plane's relative wing loading. A little more than
  /// linear scaling makes the Bomber and Rocket visibly carry momentum without
  /// making the neutral Paper Dart feel sluggish.
  static const double wingLoadingResponseExponent = 1.35;

  /// Releasing lateral input should let an airframe coast rather than snapping
  /// straight. This multiplier is applied to response while no steering input
  /// is present; high-wing-loading planes therefore drift longest.
  static const double turnMomentumCoastResponseMultiplier = 0.48;

  /// Counter-steering is intentionally slower than continuing a bank. It gives
  /// heavier planes a readable turn commitment while light folds can recover
  /// almost immediately.
  static const double turnMomentumReversalResponseMultiplier = 0.68;

  /// Input magnitude below which a plane is considered to be coasting.
  static const double turnMomentumInputDeadZone = 0.04;

  /// Safety cap for the composed steering + wind velocity. This is well above
  /// normal full-input movement, while preventing a pathological wind stack
  /// from throwing a plane through the world edge in one frame.
  static const double maxTurnMomentumSpeed = 380.0;

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
  static const double liftSnapKick = -140.0;

  /// Gentle terminal climb speed (px/s, negative = up) while holding. Deliberately
  /// mild so a press floats the plane up slowly — like a paper plane catching air.
  static const double liftCruiseSpeed = -95.0;

  /// Rate for easing the current vertical velocity toward the hold target.
  /// Lowered so the climb begins and ends without any visible jerk on hold.
  static const double liftKickDecayRate = 1.5;

  /// Retained for tuning compatibility. Release now preserves velocity fully,
  /// avoiding the visible speed change that occurred at finger-up.
  static const double glideArcPreservation = 1.0;

  /// Gravity multiplier during the glide arc phase (lighter than full gravity).
  /// Gives the "coast" feel before the natural dive takes over.
  static const double glideGravityScale = 0.55;

  /// Gravity multiplier once the glide arc is exhausted (normal fall).
  static const double fullGravityScale = 1.0;

  /// Sinusoidal bob amplitude added to vertical velocity (px/s).
  /// Gives the natural undulation of a paper plane riding air.
  /// ±10 px/s is a gentle, barely-there flutter rather than an active bounce.
  static const double oscillationAmplitude = 10.0;

  /// Oscillation frequency in cycles per second (Hz). Kept slow so the drift
  /// feels like riding air currents instead of bobbing like a cork.
  static const double oscillationFrequency = 0.8;

  /// Rate at which oscillation ramps up after release (strength units/s).
  /// Prevents a jarring jump to full oscillation immediately on release.
  static const double oscillationFadeInRate = 1.5;

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

  /// Thermal (updraft) lift force (px/s) when plane is in a thermal column.
  static const double thermalLiftForce = 160.0;

  // ── Visible Thermal Columns / Thermal Surfing ────────────────────────────
  /// A lane advertises favourable air, but the actual updraft is a visible,
  /// local column the player can choose to enter and ride.
  static const double thermalColumnMinRadius = 32.0;
  static const double thermalColumnMaxRadius = 46.0;
  static const double thermalColumnMinimumLift = 12.0;
  static const int thermalColumnParticleCount = 22;
  static const double thermalColumnFadeInRate = 5.5;
  static const double thermalColumnFadeOutRate = 2.4;

  /// Centre of the visual/surfing core, expressed as a screen-height fraction.
  static const double thermalColumnCoreYFraction = 0.56;

  /// Thermal surfing measures an orbit around the core rather than merely
  /// rewarding time spent inside it. Completing a clockwise or counter-clockwise
  /// loop earns a temporary stronger updraft.
  static const double thermalSurfOrbitHorizontalRadiusMultiplier = 0.45;
  static const double thermalSurfOrbitVerticalRadius = 92.0;
  static const double thermalSurfMinOrbitRadius = 0.34;
  static const double thermalSurfMaxOrbitRadius = 1.10;
  static const double thermalSurfRequiredRadians = 6.283185307179586;
  static const double thermalSurfProgressLiftBonus = 0.18;
  static const double thermalSurfLiftMultiplier = 1.45;
  static const double thermalSurfBonusDuration = 2.5;
  static const double thermalSurfMinimumInfluence = 0.50;

  /// Noise time scale — controls how fast wind patterns evolve.
  static const double windNoiseTimeScale = 0.4;

  /// Noise space scale per lane.
  static const double windNoiseLaneScale = 1.2;

  /// Turbulence pocket control reduction (0–1, fraction of input ignored).
  static const double turbulenceControlReduction = 0.35;

  // ── Micro-biome Turbulence Pockets ───────────────────────────────────────
  /// Natural pockets persist long enough to be read and corrected for, rather
  /// than behaving like a single-frame random gust.
  static const double turbulencePocketMinDuration = 5.0;
  static const double turbulencePocketMaxDuration = 10.0;

  /// Pockets are narrow, local weather cells expressed as a fraction of screen
  /// width. A pilot can fly around one, but cannot simply ignore its gusts.
  static const double turbulencePocketMinRadius = 0.09;
  static const double turbulencePocketMaxRadius = 0.16;
  static const int turbulencePocketMaxActive = 2;

  /// Spawn pacing is driven by obstacle events. The cooldown prevents a dense
  /// obstacle sequence from layering several cells into an unreadable wall.
  static const double turbulencePocketSpawnCooldown = 3.25;
  static const double turbulencePocketBaseSpawnChance = 0.28;
  static const double turbulencePocketStormSpawnChance = 0.58;

  /// Strength and direction-change rate for the cell's rapidly shifting wind.
  /// The signed force cycles through opposing gusts at this many cycles/second.
  static const double turbulencePocketMinIntensity = 0.62;
  static const double turbulencePocketMaxIntensity = 0.94;
  static const double turbulencePocketMinShiftHz = 1.6;
  static const double turbulencePocketMaxShiftHz = 2.8;

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
  /// Time between procedural coin batches. Kept on the longer side so coins
  /// feel like occasional rewards to chase rather than a constant shower.
  static const double coinBaseSpawnInterval = 1.6;
  static const double coinMagnetRadius = 165.0;
  static const double coinSize = 28.0;

  // ── Near-Miss (Tiered Risk Rewards) ──────────────────────────────────────
  /// Edge-clearance (hitbox-to-hitbox, px) thresholds, from outermost to
  /// tightest. The tightest tier reached at the point of closest approach is
  /// the one awarded — a graze is scored only once the plane has committed
  /// and the two bodies start separating again.
  static const double nearMissCloseShaveDistance = 32.0;
  static const double nearMissHairThinDistance = 18.0;
  static const double nearMissDeathDefyingDistance = 8.0;

  /// Points per near-miss tier (Close Shave / Hair-Thin / Death Defying).
  static const int nearMissCloseShavePoints = 25;
  static const int nearMissHairThinPoints = 50;
  static const int nearMissDeathDefyingPoints = 100;

  /// Clearance must climb this far (px) back above the recorded minimum
  /// before the pass is considered settled and the tier pays out.
  static const double nearMissSettleSlop = 2.0;

  /// Hit-stop freeze-frame triggered by a Death Defying pass.
  static const Duration deathDefyingFreeze = Duration(milliseconds: 110);

  /// Camera zoom peak for the Death Defying pulse (1.0 = no pulse).
  static const double deathDefyingCameraZoom = 1.05;

  // ── Scoring ──────────────────────────────────────────────────────────────
  /// Score per meter of distance.
  static const double scorePerMeter = 1.0;

  /// Score multiplier per coin in active combo (stacks up to comboMax).
  static const double comboMultiplierStep = 0.1;
  static const int comboMax = 20;

  /// Seconds for a FULL combo gauge ([comboMax] notches) to drain away while
  /// no coins are collected. Each coin adds exactly one notch back, so only
  /// continuous line-following can hold a high multiplier — but a brief pause
  /// merely clips off a few notches instead of wiping the combo.
  static const double comboDrainDuration = 3.5;

  /// Fraction of the combo gauge kept when an obstacle hit is absorbed by
  /// the shield — the "half the combo" penalty that replaced the old
  /// instant reset.
  static const double comboHitRetentionFraction = 0.5;

  // ── Clean Flight Streaks ─────────────────────────────────────────────────
  /// Horizontal input magnitude that counts as a committed steering direction
  /// for over-correction detection (0–1 normalized input).
  static const double overCorrectionInputThreshold = 0.55;

  /// Input must fall below this magnitude before the steering direction is
  /// considered "released" (hysteresis, prevents jitter-induced flips).
  static const double overCorrectionReleaseThreshold = 0.18;

  /// Smooth-glide streak: points paid per streak-second, escalating each
  /// consecutive second (base × n) up to the escalation cap.
  static const int cleanFlightBasePoints = 2;
  static const int cleanFlightMaxEscalation = 8;

  /// Thermal-surf streak: points paid per consecutive second riding a thermal
  /// lane (base × n) up to the escalation cap.
  static const int thermalSurfBasePoints = 3;
  static const int thermalSurfMaxEscalation = 5;

  // ── Power-ups ────────────────────────────────────────────────────────────
  static const double powerUpSpawnY = -50.0;
  static const double powerUpRecycleY = 920.0;
  static const double powerUpBaseSpawnInterval = 8.0;
  static const double shieldDuration = 0.0; // absorbs hits, no time limit
  static const double magnetDuration = 8.0; // seconds
  static const double ghostDuration = 4.0;  // seconds — phase through obstacles
  static const double slowMoDuration = 4.0; // seconds
  static const double coinRushDuration = 6.0; // seconds — 2× coin value + shower
  static const double doubleScoreDuration = 6.0; // seconds — 2x distance score
  static const double shrinkDuration = 5.0; // seconds — 0.35 hitbox
  static const double windCallerDuration = 8.0; // seconds — calm wind & thermals
  static const double blackHoleDuration = 1.5; // seconds — cosmic vacuum
  static const double turboDashDuration = 2.0; // seconds — invincible thrust dash

  /// Shrink micro-fold hitbox and visual scale factors.
  static const double shrinkHitboxScale = 0.35;
  static const double shrinkVisualScale = 0.68;

  /// Coin score multiplier while Coin Rush is active.
  static const double coinRushValueMultiplier = 2.0;

  /// How often Coin Rush rains down a coin shower (seconds).
  static const double coinRushShowerInterval = 0.8;

  /// Coin magnet pull speed (px/s) while Magnet is active.
  static const double coinMagnetPullSpeed = 340.0;

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

  // ── Virtual Joystick Steering ────────────────────────────────────────────
  /// Radius (px) of the floating joystick base. The knob travels within this
  /// circle; full deflection at the rim maps to full steering.
  static const double joystickRadius = 56.0;

  /// Dead zone (px) around the stick center before steering kicks in.
  static const double joystickDeadZone = 10.0;

  /// Smoothing factor for joystick horizontal input (low-pass). Higher = snappier.
  static const double joystickSmoothingAlpha = 0.28;

  /// Max horizontal speed at full stick deflection (px/s). Slightly higher than
  /// tilt so thumb steering feels responsive.
  static const double joystickMaxSteerSpeed = 170.0;

  // ── Snap Burst (Paper-Snap) ───────────────────────────────────────────────
  static const int snapMaxCharges = 2;
  /// Snap burst velocity (px/s upward, negative).
  static const double snapBurstVelocity = -252.0; // 1.8 × liftSnapKick

  /// Flick-up gesture thresholds.
  static const double snapFlickMinDistance = 70.0; // px upward travel
  static const double snapFlickMaxDurationMs = 220.0; // ms
  static const double snapFlickMinVelocity = 320.0; // px/s upward

  /// Distance (meters) to recharge one snap charge.
  static const double snapRechargeMeters = 200.0;

  // ── Snap Charge Ring ─────────────────────────────────────────────────────
  static const double snapRingRadius = 32.0;
  static const double snapRingStrokeWidth = 3.0;
  static const double snapRingGapRadians = 0.22; // gap between segments

  // ── Soft Altitude Ceiling ─────────────────────────────────────────────────
  /// Hard ceiling Y (px from top). Plane never goes above this.
  static const double ceilingY = 40.0;

  /// Soft zone start (px from top). Resistance begins fading in here.
  static const double ceilingSoftY = 64.0;

  /// Velocity damping factor applied per frame while in soft zone and moving up.
  static const double ceilingResistanceDamping = 0.55;

  /// Downward stall push (px/s) applied briefly on ceiling contact.
  static const double ceilingStallPush = 85.0;

  /// Duration (s) of the nose-down dip animation after hitting ceiling.
  static const double ceilingDipDuration = 0.34;

  /// Dip angle (radians) added briefly when stalling at ceiling.
  static const double ceilingDipAngle = 0.32;

  // ── UI Animation ─────────────────────────────────────────────────────────
  static const Duration screenTransition = Duration(milliseconds: 300);

  /// Hit-stop after the plane crashes before the results screen begins its
  /// transition. Kept short so the player never stares at a paused/black frame
  /// for a noticeable beat — long enough to register the impact + crash sting,
  /// no longer.
  static const Duration crashSlowMoFreeze = Duration(milliseconds: 80);

  // ── Juice / Game Feel (Task 6) ────────────────────────────────────────────
  /// Camera begins pulling back once world scroll speed passes this (px/s).
  static const double highSpeedCameraThreshold = 350.0;

  /// Camera zoom factor at max speed (1.0 = default framing, <1 pulls back).
  static const double highSpeedZoomOut = 0.95;

  /// Camera bank angle (radians) at full lateral speed (~1.7° each way).
  static const double cameraBankMax = 0.03;

  /// Coin-combo chime volume (0..1), multiplied by the SFX volume setting.
  static const double coinChimeVolume = 0.55;

  // ── Plane Signature Abilities (Task 7) ────────────────────────────────────

  /// Paper Dart: +15% extra distance score.
  static const double dartDistanceBonusMultiplier = 1.15;

  /// Glider Fold: built-in weak coin attraction (smaller/slower than Magnet).
  static const double gliderCoinAttractRadius = 95.0;
  static const double gliderCoinAttractSpeed = 140.0;

  /// Glider: wider glide arc → lighter glide gravity (20% floatier).
  static const double gliderGlideGravityFactor = 0.80;

  /// Glider: +20% longer thermal float (thermal lift bonus multiplier).
  static const double gliderThermalBonusMultiplier = 1.20;

  /// Stunt Fold: +50% score from near-misses.
  static const double stuntNearMissMultiplier = 1.50;

  /// Stunt Fold: double snap burst recharge speed.
  static const double stuntSnapRechargeMultiplier = 2.0;

  /// Stealth Jet: streamlined smaller hitbox and faster dive recovery.
  static const double stealthHitboxScale = 0.42;
  static const double stealthDiveRecoveryGravityScale = 0.88;
  static const double stealthWindControlBonus = 1.08;

  /// Origami Crane: free brush-offs against tree branches per run.
  static const int craneBranchCharges = 1;

  /// Origami Butterfly: floaty fall, auto-sway, +40% thermal lift.
  static const double butterflyFallSpeed = 0.75;
  static const double butterflyThermalBonusMultiplier = 1.40;

  /// Paper Bomber: heavy payload, starts run with 2 shield charges.
  static const int bomberStartShieldCharges = 2;

  /// Interceptor: agile handling, 0 coin attract.
  static const double interceptorTurnSpeed = 1.25;

  /// Soaring Albatross: master glider, 2x glide streak points.
  static const double albatrossGlideStreakMultiplier = 2.0;
  static const double albatrossGlideDecayReduction = 0.50;

  // ── Paper Skins ───────────────────────────────────────────────────────────
  static const List<String> skinAssetHints = [
    'Plain Paper',
    'Newspaper Print',
    'Graph Paper',
    'Notebook Doodle',
    'Holographic Foil',
    'Watercolor Wash',
    'Gold Leaf',
  ];

  // ── Challenges ─────────────────────────────────────────────────────────────
  /// Daily: 3 challenges refreshed at midnight.
  static const int dailyChallengeCount = 3;

  /// Weekly: 3 challenges refreshed each Monday.
  static const int weeklyChallengeCount = 3;

  // ── Zen Flight / Endless Breeze (Task 8) ───────────────────────────────────
  /// Zen world scrolls slower and ramps far more gently than classic — the
  /// world drifts by instead of rushing at the player.
  static const double zenBaseScrollSpeed = 100.0;
  static const double zenScrollSpeedPerMeter = 0.08;
  static const double zenMaxScrollSpeed = 280.0;

  /// Global wind calm-down multiplier for Zen (1.0 = classic strength).
  static const double zenWindScale = 0.55;

  /// Seconds of immunity after a Zen bump so the plane doesn't rattle.
  static const double zenBounceCooldown = 1.0;

  /// Lateral + upward push applied to the plane on a Zen bump (px/s).
  static const double zenBouncePushX = 220.0;
  static const double zenBouncePushY = -70.0;

  /// Zen has no crash — the plane softly bounces off the bottom of the world.
  static const double zenSoftFloorY = 770.0;
  static const double zenSoftFloorBounce = -80.0;

  /// Zen biomes: Backyard Morning up to this distance, then Mountain Pass.
  static const double zenBiomeMountainAt = 400.0;

  // ── Daily Seeded Flight (Task 8) ───────────────────────────────────────────
  /// Knuth multiplicative hash constants used to turn the UTC day index into
  /// the daily seed. Any player anywhere gets the same seed on the same day.
  static const int dailySeedSaltA = 2654435761;
  static const int dailySeedSaltB = 1013904223;

  // ── Precision Trials (Task 8) ──────────────────────────────────────────────
  /// Course "end" marker: the run completes this many meters after the last
  /// scripted element reaches the plane row.
  static const double trialFinishMarginMeters = 40.0;

  /// Lead distance (m) between a spawn event and the element reaching the
  /// plane row, matching obstacleSpawnY (-80) and the plane start row.
  static const double trialObstacleLeadMeters = 63.0;

  /// Same, for bird/drone/storm-cloud style early-warning spawns (-260).
  static const double trialEarlyWarningLeadMeters = 81.0;

  /// Same, for coins / power-ups spawning at -40 / -50.
  static const double trialCoinLeadMeters = 59.0;

  /// Seconds of hit-stop after a trial crash before the results push. Short
  /// enough not to read as a hang/black screen, long enough to register impact.
  static const double trialCrashFreezeSeconds = 0.35;
}

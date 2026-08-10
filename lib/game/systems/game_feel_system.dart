import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/audio_synth.dart';
import '../../core/utils/math_utils.dart';
import '../../models/settings_model.dart';
import '../../providers/game_session_provider.dart';
import '../../providers/settings_provider.dart';
import '../paper_flight_game.dart';

/// The "juice" layer — adaptive flight audio, dynamic camera, speed streaks,
/// coin-combo chime melody and rich haptics (Task 6).
///
/// Responsibilities (each respects the player's SFX / haptic settings):
///
///  * **Adaptive wind** — a continuously looping `wind_loop.wav` whose volume
///    and playback rate (pitch) track world scroll speed + vertical dive speed.
///    Gated by the SFX toggle and scaled by SFX volume (per spec).
///  * **Dynamic camera** — pulls the view back (zoom-out) once scroll speed
///    passes ~350 px/s. (The viewport previously also banked toward lateral
///    movement, tilting the whole world with the plane; that is intentionally
///    disabled now — the world stays level.)
///  * **Vignette / speed streaks** — white motion lines along the viewport
///    edges + a radial vignette that intensify on high-speed dives / Coin Rush.
///  * **Coin-combo chime** — a rising pentatonic note per combo count, forming
///    a melody as the combo grows.
///  * **Haptics** — coin tap, near-miss click, crash/shield shudder, and a
///    gentle periodic hum while riding a thermal updraft.
///
/// Note: a synthesized "paper crease" flutter used to play on a ~0.28 s loop
/// while the player held the screen (or carved a tight turn). It was removed
/// because holding is the core flight input, so the rustle repeated
/// continuously during normal play and read as an unwanted noise.
///
/// The camera zoom/rotation modify `game.camera.viewfinder` (Flame's zoom and
/// angle both pivot about the viewport centre), so the framing is preserved.
class GameFeelSystem extends Component with HasGameRef<PaperFlightGame> {
  // ── Continuous wind player ────────────────────────────────────────────────
  AudioPlayer? _wind;
  bool _windReady = false;
  bool _windStarting = false;
  double _windVol = 0.0;
  double _windTarget = 0.0;
  double _windRate = 1.0;

  // ── Zen Flight ambient pad (Task 8) ───────────────────────────────────────
  AudioPlayer? _zenMusic;
  bool _zenMusicStarting = false;

  // ── Camera easing state ───────────────────────────────────────────────────
  double _zoom = 1.0;

  // ── Streak overlay animation ──────────────────────────────────────────────
  double _streakIntensity = 0.0;
  double _streakPulse = 0.0;

  // ── Throttles ─────────────────────────────────────────────────────────────
  double _thermalHapticsTimer = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _kickStartWind();
  }

  @override
  void onRemove() {
    dispose();
    super.onRemove();
  }

  /// Releases the continuous wind and Zen-music audio players. Safe to call
  /// multiple times. Exposed so the host game can tear audio down
  /// deterministically on dispose instead of relying solely on onRemove.
  void dispose() {
    _disposeWind();
    stopZenMusic();
  }

  // ── Zen ambient music ─────────────────────────────────────────────────────

  /// Starts the looping synthesized ambient pad for Zen Flight. Respects the
  /// music toggle + volume; never blocks the game loop.
  void startZenMusic() {
    if (_zenMusic != null || _zenMusicStarting) return;
    _zenMusicStarting = true;
    _startZenMusicAsync();
  }

  Future<void> _startZenMusicAsync() async {
    try {
      final settings = _settings();
      if (!settings.musicEnabled) {
        _zenMusicStarting = false;
        return;
      }
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSourceBytes(AudioSynth.ambientPad(volume: 0.8));
      await player.setVolume(settings.musicVolume);
      _zenMusic = player;
      await player.resume();
    } catch (_) {
      _zenMusic = null;
    } finally {
      _zenMusicStarting = false;
    }
  }

  void stopZenMusic() {
    try {
      _zenMusic?.stop();
      _zenMusic?.dispose();
    } catch (_) {}
    _zenMusic = null;
    _zenMusicStarting = false;
  }

  // ── Lifecycle hooks called by PaperFlightGame ─────────────────────────────

  /// Resets transient per-run state (thermal-haptics throttle timer).
  void reset() {
    _thermalHapticsTimer = 0;
  }

  /// Instantly silences the wind ambient. Used where the game loop is frozen
  /// (pause menu, crash freeze) so `update` can't ease the volume down itself.
  void silence() {
    _windTarget = 0;
    _windVol = 0;
    try {
      _wind?.setVolume(0);
    } catch (_) {}
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    final playing = gameRef.phase == GamePhase.playing;

    _updateWind(dt, playing);
    _updateCamera(dt, playing);
    _updateStreakOverlay(dt, playing);
    _updateThermalHaptics(dt, playing);

    super.update(dt);
  }

  // ── Continuous wind (SFX-gated ambient) ───────────────────────────────────

  void _kickStartWind() {
    if (_windReady || _windStarting) return;
    _windStarting = true;
    _startWindAsync();
  }

  /// Starts the looping wind player. Starts muted (volume 0) and never waits
  /// on the futures from update, so a transient audio failure is harmless.
  Future<void> _startWindAsync() async {
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource('audio/wind_loop.wav'));
      await player.setVolume(0.0); // muted until the first update sets it
      _wind = player;
      await player.resume();
    } catch (_) {
      _wind = null;
    } finally {
      _windReady = true;
      _windStarting = false;
    }
  }

  void _updateWind(double dt, bool playing) {
    final settings = _settings();
    final wantWind = playing && settings.sfxEnabled;
    final volume = settings.sfxVolume;

    if (!_windReady) {
      if (wantWind) _kickStartWind();
      return;
    }
    final wind = _wind;
    if (wind == null) return;

    if (!wantWind) {
      _windTarget = 0.0;
      _windRate = 1.0;
    } else {
      // World scroll speed base..max → 0..1, plus dive (downward) speed.
      final speedFactor = ((gameRef.scrollSpeed - GameConfig.baseScrollSpeed) /
              (GameConfig.maxScrollSpeed - GameConfig.baseScrollSpeed))
          .clamp(0.0, 1.0)
          .toDouble();
      final dive = (gameRef.plane.verticalVelocity / GameConfig.maxFallSpeed)
          .clamp(0.0, 1.0)
          .toDouble();
      final level = (0.28 + speedFactor * 0.5 + dive * 0.4).clamp(0.0, 1.0);
      _windTarget = level * volume;
      // Faster + diving → brighter/lower wind rush.
      _windRate = 1.0 + speedFactor * 0.35 + dive * 0.25;
    }

    // Smoothly glide volume & pitch toward their targets.
    _windVol = MathUtils.lerp(_windVol, _windTarget, (4.0 * dt).clamp(0.0, 1.0));
    unawaited(wind.setVolume(_windVol));
    unawaited(wind.setPlaybackRate(_windRate));
  }

  void _disposeWind() {
    try {
      _wind?.dispose();
    } catch (_) {}
    _wind = null;
    _windReady = false;
  }

  // ── Dynamic camera: zoom-out at high speed ────────────────────────────────
  //
  // Note: the viewport previously also *banked* (rotated) toward the plane's
  // lateral velocity, which tilted the whole world with the plane. That is
  // disabled on purpose now — the world stays perfectly level; only a subtle
  // zoom-out at high speed remains.

  void _updateCamera(double dt, bool playing) {
    final viewfinder = gameRef.camera.viewfinder;

    if (!playing) {
      // Ease back to neutral when idle / paused / dying / game over.
      _zoom = MathUtils.lerp(_zoom, 1.0, (5.0 * dt).clamp(0.0, 1.0));
    } else {
      // Zoom-out: pull back once scroll speed passes the threshold.
      final zoomTarget =
          gameRef.scrollSpeed > GameConfig.highSpeedCameraThreshold
              ? MathUtils
                  .remap(
                    gameRef.scrollSpeed,
                    GameConfig.highSpeedCameraThreshold,
                    GameConfig.maxScrollSpeed,
                    1.0,
                    GameConfig.highSpeedZoomOut,
                  )
                  .clamp(GameConfig.highSpeedZoomOut, 1.0)
                  .toDouble()
              : 1.0;
      _zoom = MathUtils.lerp(_zoom, zoomTarget, (3.0 * dt).clamp(0.0, 1.0));
    }

    // World never tilts — angle is pinned level.
    viewfinder.zoom = _zoom;
    viewfinder.angle = 0.0;
  }

  // ── Vignette / speed streaks overlay ──────────────────────────────────────

  void _updateStreakOverlay(double dt, bool playing) {
    double target = 0;
    if (playing) {
      final session = gameRef.ref.read(gameSessionProvider);
      final coinRush = session.activePowerUps.contains(PowerUpType.coinRush);
      final speedFactor = ((gameRef.scrollSpeed - 300) /
              (GameConfig.maxScrollSpeed - 300))
          .clamp(0.0, 1.0)
          .toDouble();
      final dive = (gameRef.plane.verticalVelocity / GameConfig.maxFallSpeed)
          .clamp(0.0, 1.0)
          .toDouble();
      target = math.max(coinRush ? 0.8 : 0.0, math.max(speedFactor, dive));
    }
    _streakIntensity = MathUtils.lerp(
        _streakIntensity, target, (3.0 * dt).clamp(0.0, 1.0));
    if (_streakIntensity > 0.02) _streakPulse += dt * 16.0;
  }

  @override
  void render(Canvas canvas) {
    final inten = _streakIntensity;
    if (inten <= 0.03) return;

    final w = GameConfig.designWidth;
    final h = GameConfig.designHeight;

    // White motion streaks hugging the left/right edges.
    final streak = Paint()
      ..color = Color.fromRGBO(
          255, 255, 255, (0.08 + inten * 0.24).clamp(0.0, 0.34).toDouble())
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (var side = 0; side < 2; side++) {
      final x = side == 0 ? 6.0 : w - 6.0;
      for (var i = 0; i < 5; i++) {
        final y = (i * 117.0 + (_streakPulse * 220.0 % 110.0)) % (h - 40);
        final len = 24.0 + inten * 46.0 + math.sin(_streakPulse * 0.7 + i) * 8.0;
        final dir = side == 0 ? 1.0 : -1.0;
        canvas.drawLine(Offset(x, y), Offset(x + dir * len * 0.3, y), streak);
      }
    }

    // Radial vignette — darkens the corners as speed/build-up rises.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x00000000),
          Color.fromRGBO(0, 0, 0, (0.28 * inten).clamp(0.0, 0.5).toDouble()),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignette);

    super.render(canvas);
  }

  // ── Thermal hum haptics (periodic light ticks while riding a thermal) ─────

  void _updateThermalHaptics(double dt, bool playing) {
    if (!playing || !_settings().hapticEnabled) return;
    if (gameRef.plane.isInThermal) {
      _thermalHapticsTimer -= dt;
      if (_thermalHapticsTimer <= 0) {
        _thermalHapticsTimer = 0.15;
        HapticFeedback.lightImpact();
      }
    } else {
      _thermalHapticsTimer = 0;
    }
  }

  // ── Public event hooks (called from scoring / game) ───────────────────────

  /// Coin collected — light tap + ascending chime for the current combo.
  void onCoinCollected(int comboCount) {
    if (_settings().hapticEnabled) HapticFeedback.lightImpact();
    _playChimeForCombo(comboCount);
  }

  /// Near-miss confirmed — sharp medium click.
  void onNearMiss() {
    if (_settings().hapticEnabled) HapticFeedback.mediumImpact();
  }

  /// Obstacle crash — heavy shudder.
  void onCrash() {
    if (_settings().hapticEnabled) HapticFeedback.heavyImpact();
  }

  /// Shield absorbs a hit — heavy shudder.
  void onShieldBreak() {
    if (_settings().hapticEnabled) HapticFeedback.heavyImpact();
  }

  // ── Audio one-shots ───────────────────────────────────────────────────────

  void _playChimeForCombo(int combo) {
    if (!_settings().sfxEnabled) return;
    final scale = AudioSynth.chimeScaleHz;
    final idx = (combo - 1) % scale.length;
    final brightness = (0.5 + (combo / 20.0)).clamp(0.5, 1.5).toDouble();
    final bytes = AudioSynth.chime(
      scale[idx],
      harmonicLevel: brightness,
      volume: GameConfig.coinChimeVolume,
    );
    _playBytes(bytes, volume: _settings().sfxVolume);
  }

  /// Plays a synthesized byte buffer with a short-lived player that disposes
  /// itself on completion (mirrors the existing near-miss sting pattern).
  void _playBytes(Uint8List bytes, {double volume = 0.6}) {
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) async {
        await player.dispose();
      });
      unawaited(_playBytesAsync(player, bytes, volume));
    } catch (_) {
      // Audio safely ignored if unsupported (tests / headless).
    }
  }

  Future<void> _playBytesAsync(
    AudioPlayer player,
    Uint8List bytes,
    double volume,
  ) async {
    try {
      await player.play(BytesSource(bytes), volume: volume);
    } catch (_) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  SettingsModel _settings() {
    try {
      return gameRef.ref.read(settingsProvider);
    } catch (_) {
      return SettingsModel();
    }
  }
}

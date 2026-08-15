import '../core/enums/game_enums.dart';
import '../providers/game_session_provider.dart';

/// Compact, once-per-frame cache of the session's live power-up situation.
///
/// Flame components read this snapshot instead of reaching into Riverpod from
/// the frame hot path. [PaperFlightGame] already reads the session provider
/// exactly once per simulation tick; it calls [syncFrom] with that state and
/// every coin, obstacle and wind-system sample below it then reads these
/// booleans for free. No component ever pays a provider lookup per frame.
class LivePowerUpState {
  /// Ghost phasing — obstacles ignore near-miss tracking, birds get scared.
  bool ghostActive = false;

  /// Magnet coin pull.
  bool magnetActive = false;

  /// Hangar evolution level of the Magnet (1 or 2). This is save data, not
  /// session state — the game refreshes it on run start and at the periodic
  /// runtime sync instead of every frame.
  int magnetLevel = 1;

  /// Shield bubble — drones advertise an EMP clash while it is up.
  bool shieldActive = false;

  /// Black Hole cosmic vacuum — pulls coins and small hazards into the vortex.
  bool blackHoleActive = false;

  /// Giant Mode — the plane is oversized and smashes hazards it touches.
  bool giantActive = false;

  /// Slow-Mo — the world and simulation run at reduced timescale.
  bool slowMoActive = false;

  /// Coin Rush — doubled coin value + periodic showers.
  bool coinRushActive = false;

  /// Double Score — doubled distance score.
  bool doubleScoreActive = false;

  /// Cursed Magnet (corrupted pickup) — pulls coins *and* hazards at the plane.
  bool cursedMagnetActive = false;

  /// Unstable Ghost (corrupted pickup) — ghost phasing with forced teleports.
  bool unstableGhostActive = false;

  void syncFrom(GameSessionState session) {
    final active = session.activePowerUps;
    ghostActive = active.contains(PowerUpType.ghost);
    magnetActive = active.contains(PowerUpType.magnet);
    shieldActive = session.shieldActive;
    blackHoleActive = active.contains(PowerUpType.blackHole);
    giantActive = active.contains(PowerUpType.giant);
    slowMoActive = active.contains(PowerUpType.slowMo);
    coinRushActive = active.contains(PowerUpType.coinRush);
    doubleScoreActive = active.contains(PowerUpType.doubleScore);
    cursedMagnetActive = session.activeCorruptedPowerUps
        .contains(CorruptedPowerUpType.cursedMagnet);
    unstableGhostActive = session.activeCorruptedPowerUps
        .contains(CorruptedPowerUpType.unstableGhost);
  }

  void reset() {
    ghostActive = false;
    magnetActive = false;
    magnetLevel = 1;
    shieldActive = false;
    blackHoleActive = false;
    giantActive = false;
    slowMoActive = false;
    coinRushActive = false;
    doubleScoreActive = false;
    cursedMagnetActive = false;
    unstableGhostActive = false;
  }
}

/// Optional handcrafted layout overrides for a scripted obstacle spawn.
///
/// Trial courses (and the daily seeded run) use these to pin down the exact
/// geometry of an obstacle instead of letting it roll its own random values.
/// Every field is optional — unset fields fall back to the normal random
/// behaviour, so classic endless mode is untouched.
class ObstacleScript {
  const ObstacleScript({
    this.gapCenterX,
    this.gapWidth,
    this.driftAmp,
    this.driftFreq,
    this.fromLeft,
  });

  /// Corridor centre for gap-type obstacles (power lines, buildings).
  /// The gap is centred here: gapX = gapCenterX - gapWidth / 2.
  final double? gapCenterX;

  /// Exact gap width (px) for gap-type obstacles.
  final double? gapWidth;

  /// Lateral drift/sway amplitude (px) for drifting obstacles
  /// (birds, balloons, kites). 0 pins the obstacle in place.
  final double? driftAmp;

  /// Lateral drift frequency (Hz) for drifting obstacles.
  final double? driftFreq;

  /// Spawn side for tree branches — true = left edge, false = right edge.
  final bool? fromLeft;
}

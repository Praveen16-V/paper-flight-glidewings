import 'dart:math';

/// Lightweight value-noise implementation — no external packages required.
/// Used by the wind system to produce smooth, repeatable lane values.
///
/// Returns values in [-1, 1].
class ValueNoise {
  ValueNoise({int? seed}) {
    final rng = Random(seed ?? 42);
    _table = List.generate(512, (_) => rng.nextDouble() * 2.0 - 1.0);
  }

  late final List<double> _table;

  /// 1-D smooth noise at position [x].
  double noise1d(double x) {
    final ix = x.floor() & 255;
    final fx = x - x.floorToDouble();
    final u = _fade(fx);
    final a = _table[ix];
    final b = _table[(ix + 1) & 255];
    return _lerp(a, b, u);
  }

  /// 2-D smooth noise at (x, y) — used as noise(laneIndex, time).
  double noise2d(double x, double y) {
    final ix = x.floor() & 255;
    final iy = y.floor() & 255;
    final fx = x - x.floorToDouble();
    final fy = y - y.floorToDouble();
    final uu = _fade(fx);
    final vv = _fade(fy);

    final aa = _table[(ix + iy) & 255];
    final ab = _table[(ix + iy + 1) & 255];
    final ba = _table[(ix + 1 + iy) & 255];
    final bb = _table[(ix + 1 + iy + 1) & 255];

    return _lerp(
      _lerp(aa, ba, uu),
      _lerp(ab, bb, uu),
      vv,
    );
  }

  /// Fractal Brownian Motion — sums [octaves] noise layers for richer texture.
  double fbm(double x, double y, {int octaves = 3, double lacunarity = 2.0, double gain = 0.5}) {
    double value = 0.0;
    double amplitude = 0.5;
    double frequency = 1.0;
    for (int i = 0; i < octaves; i++) {
      value += noise2d(x * frequency, y * frequency) * amplitude;
      frequency *= lacunarity;
      amplitude *= gain;
    }
    return value;
  }

  static double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);
  static double _lerp(double a, double b, double t) => a + t * (b - a);
}

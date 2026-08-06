import 'dart:math';

/// Shared math helpers used across game systems.
abstract class MathUtils {
  static final Random _rng = Random();

  /// Clamp [value] between [min] and [max].
  static double clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  /// Linear interpolation.
  static double lerp(double a, double b, double t) => a + (b - a) * t;

  /// Map [value] from [inMin..inMax] to [outMin..outMax].
  static double remap(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax,
  ) {
    if (inMax == inMin) return outMin;
    return outMin + (value - inMin) / (inMax - inMin) * (outMax - outMin);
  }

  /// Random double in [min, max).
  static double randomRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);

  /// Random int in [min, max] inclusive.
  static int randomInt(int min, int max) =>
      min + _rng.nextInt(max - min + 1);

  /// Random pick from list.
  static T pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  /// Weighted random pick. [weights] must be the same length as [items].
  static T weightedPick<T>(List<T> items, List<double> weights) {
    assert(items.length == weights.length);
    final total = weights.fold(0.0, (a, b) => a + b);
    double roll = _rng.nextDouble() * total;
    for (int i = 0; i < items.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return items[i];
    }
    return items.last;
  }

  /// Low-pass filter step: smooth jittery sensor input.
  /// [alpha] 0 = no filtering (raw), 1 = frozen.
  static double lowPass(double previous, double current, double alpha) =>
      previous + alpha * (current - previous);

  /// Distance between two 2-D points.
  static double distance(double x1, double y1, double x2, double y2) =>
      sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));

  /// Degrees to radians.
  static double toRad(double deg) => deg * pi / 180.0;
}

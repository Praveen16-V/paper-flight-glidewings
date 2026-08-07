import '../core/constants/game_config.dart';

/// Derives the deterministic daily seed for the Daily Seeded Flight mode.
///
/// The seed is a pure function of the **UTC calendar day** — so every player
/// on Earth gets the identical wind patterns, obstacle placements and coin
/// layouts on the same day, regardless of their local timezone. The daily
/// run "resets" at UTC midnight.
abstract class DailySeedService {
  /// Seed for the UTC day containing [date].
  static int seedForDate(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final daysSinceEpoch = day.difference(DateTime.utc(1970)).inDays;
    // Knuth multiplicative hash — mixes the day counter into a stable,
    // well-distributed 31-bit seed.
    return (daysSinceEpoch * GameConfig.dailySeedSaltA +
            GameConfig.dailySeedSaltB) &
        0x7fffffff;
  }

  /// Seed for today (UTC).
  static int seedForNow() => seedForDate(DateTime.now());

  /// UTC midnight after [date] — when the next daily run becomes available.
  static DateTime nextResetUtc(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return day.add(const Duration(days: 1));
  }

  /// Human-friendly label shown on the daily screen, e.g. "Daily #12845".
  static String label(int seed) => 'Daily #$seed';

  /// Deterministic seeded wind condition label for the daily flight.
  static String windLabel(int seed) {
    const conditions = [
      'Strong Crosswinds',
      'Thermal Updrafts',
      'Turbulent Gusts',
      'Swirling Breezes',
      'Gentle Tailwinds',
      'Shear Winds',
    ];
    return conditions[seed.abs() % conditions.length];
  }
}

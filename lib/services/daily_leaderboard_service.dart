import 'package:hive_flutter/hive_flutter.dart';

import 'daily_seed_service.dart';

/// One row of the daily seeded leaderboard.
class DailyLeaderboardEntry {
  const DailyLeaderboardEntry({
    required this.playerName,
    required this.score,
    required this.distanceMeters,
    required this.dateUtc,
  });

  final String playerName;
  final int score;
  final double distanceMeters;
  final DateTime dateUtc;

  /// Serialized as "name|score|distance|epochMs" — the local implementation
  /// stores history as plain strings so no extra Hive adapter is needed.
  String toStorageString() =>
      '$playerName|$score|${distanceMeters.toStringAsFixed(1)}|${dateUtc.millisecondsSinceEpoch}';

  static DailyLeaderboardEntry? fromStorageString(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final score = int.tryParse(parts[1]);
    final dist = double.tryParse(parts[2]);
    final ms = int.tryParse(parts[3]);
    if (score == null || dist == null || ms == null) return null;
    return DailyLeaderboardEntry(
      playerName: parts[0],
      score: score,
      distanceMeters: dist,
      dateUtc: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    );
  }
}

/// Result of submitting / querying a daily score.
class DailyLeaderboardResult {
  const DailyLeaderboardResult({
    required this.seed,
    required this.score,
    required this.distanceMeters,
    required this.isPersonalBest,
  });

  final int seed;
  final int score;
  final double distanceMeters;
  final bool isPersonalBest;
}

/// Pluggable leaderboard backend for the Daily Seeded Flight.
///
/// The default implementation ([LocalDailyLeaderboardService]) is fully
/// offline: scores are stored on-device and the daily seed guarantees the run
/// itself is identical to every other player's. Swap [DailyLeaderboardService]
/// for a real backend (Firestore / REST) without touching game code.
abstract class DailyLeaderboardService {
  /// Records this player's run for [seed]. Returns the result including
  /// whether it beat their own best.
  Future<DailyLeaderboardResult> submitScore({
    required int seed,
    required int score,
    required double distanceMeters,
  });

  /// This player's best score for [seed] (null if never played).
  Future<DailyLeaderboardResult?> bestForSeed(int seed);

  /// Most recent submissions (any seed), newest first — powers the "recent
  /// flights" strip on the daily screen.
  Future<List<DailyLeaderboardEntry>> recentEntries({int limit = 5});
}

/// Offline implementation — persisted in a dedicated Hive box.
class LocalDailyLeaderboardService implements DailyLeaderboardService {
  static const String _boxName = 'daily_leaderboard';
  static const String _historyKey = 'history';
  static const int _historyCap = 30;

  Box get _box => Hive.box(_boxName);

  List<DailyLeaderboardEntry> _readHistory() {
    final raw = _box.get(_historyKey) as List? ?? const [];
    return raw
        .whereType<String>()
        .map(DailyLeaderboardEntry.fromStorageString)
        .whereType<DailyLeaderboardEntry>()
        .toList();
  }

  Future<void> _writeHistory(List<DailyLeaderboardEntry> entries) async {
    await _box.put(
      _historyKey,
      entries.map((e) => e.toStorageString()).toList(),
    );
  }

  @override
  Future<DailyLeaderboardResult> submitScore({
    required int seed,
    required int score,
    required double distanceMeters,
  }) async {
    final history = _readHistory();
    final previous = _bestForSeedFrom(history, seed);
    final isPersonalBest =
        previous == null || score > previous.score || (score == previous.score && distanceMeters > previous.distanceMeters);

    final entry = DailyLeaderboardEntry(
      playerName: 'You',
      score: score,
      distanceMeters: distanceMeters,
      dateUtc: DateTime.now().toUtc(),
    );
    history.insert(0, entry);
    if (history.length > _historyCap) {
      history.removeRange(_historyCap, history.length);
    }
    await _writeHistory(history);

    return DailyLeaderboardResult(
      seed: seed,
      score: score,
      distanceMeters: distanceMeters,
      isPersonalBest: isPersonalBest,
    );
  }

  @override
  Future<DailyLeaderboardResult?> bestForSeed(int seed) async {
    final best = _bestForSeedFrom(_readHistory(), seed);
    if (best == null) return null;
    return DailyLeaderboardResult(
      seed: seed,
      score: best.score,
      distanceMeters: best.distanceMeters,
      isPersonalBest: true,
    );
  }

  DailyLeaderboardEntry? _bestForSeedFrom(
      List<DailyLeaderboardEntry> history, int seed) {
    DailyLeaderboardEntry? best;
    for (final e in history) {
      // The entry's seed isn't stored directly — the daily seed is a pure
      // function of the UTC date, so we can recover it from the entry date.
      if (DailySeedService.seedForDate(e.dateUtc) != seed) continue;
      if (best == null ||
          e.score > best.score ||
          (e.score == best.score && e.distanceMeters > best.distanceMeters)) {
        best = e;
      }
    }
    return best;
  }

  @override
  Future<List<DailyLeaderboardEntry>> recentEntries({int limit = 5}) async {
    final history = _readHistory();
    return history.take(limit).toList();
  }
}

/// Swappable instance — game code only ever talks to this static.
abstract class DailyLeaderboard {
  static DailyLeaderboardService instance = LocalDailyLeaderboardService();
}

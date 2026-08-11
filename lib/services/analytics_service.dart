import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import '../game/diagnostics/runtime_diagnostics.dart';

/// Central event contract for product, balance, economy, ad, and runtime data.
///
/// Event names are intentionally stable and snake_case. Every custom event is
/// tagged with [GameConfig.balanceVersion] so tuning experiments can be
/// compared by cohort instead of mixing incompatible balance curves.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  DateTime? _appSessionStartedAt;

  Map<String, Object> _withBuildContext([Map<String, Object>? parameters]) {
    return <String, Object>{
      'balance_version': GameConfig.balanceVersion,
      ...?parameters,
    };
  }

  Future<void> _safeEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: _withBuildContext(parameters),
      );
    } catch (_) {
      // Telemetry must never interrupt gameplay, navigation, or ad callbacks.
    }
  }

  // ── App sessions / retention ─────────────────────────────────────────────

  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (_) {}
  }

  /// Starts one foreground session. Repeated lifecycle notifications are
  /// de-duplicated until [endAppSession] closes the current session.
  void startAppSession() {
    if (_appSessionStartedAt != null) return;
    _appSessionStartedAt = DateTime.now();
    unawaited(_safeEvent('app_session_started'));
  }

  Future<void> endAppSession({required String reason}) async {
    final startedAt = _appSessionStartedAt;
    if (startedAt == null) return;
    _appSessionStartedAt = null;
    final seconds = DateTime.now().difference(startedAt).inSeconds;
    await _safeEvent('app_session_ended', {
      'duration_seconds': seconds,
      'end_reason': reason,
    });
  }

  Future<void> setProgressionProperties({
    required int lifetimeRuns,
    required int highScore,
  }) async {
    try {
      await Future.wait([
        _analytics.setUserProperty(
          name: 'lifetime_run_band',
          value: _runBand(lifetimeRuns),
        ),
        _analytics.setUserProperty(
          name: 'high_score_band',
          value: _scoreBand(highScore),
        ),
      ]);
    } catch (_) {}
  }

  String _runBand(int runs) {
    if (runs == 0) return '0';
    if (runs < 3) return '1_2';
    if (runs < 10) return '3_9';
    if (runs < 25) return '10_24';
    if (runs < 100) return '25_99';
    return '100_plus';
  }

  String _scoreBand(int score) {
    if (score < 500) return 'under_500';
    if (score < 2000) return '500_1999';
    if (score < 10000) return '2000_9999';
    return '10000_plus';
  }

  // ── Core game loop KPIs ──────────────────────────────────────────────────

  Future<void> logRunStarted({
    required GameMode mode,
    required ControlScheme controlScheme,
    required int lifetimeRunNumber,
    required int runSeed,
    required int rngAlgorithmVersion,
    int? trialId,
  }) {
    return _safeEvent('run_started', {
      'mode': mode.name,
      'control_scheme': controlScheme.name,
      'lifetime_run_number': lifetimeRunNumber,
      'run_seed': runSeed,
      'rng_algorithm_version': rngAlgorithmVersion,
      if (trialId != null) 'trial_id': trialId,
      // Balance exposure values make dashboards useful even if a build label
      // is accidentally reused.
      'obstacle_interval_ms':
          (GameConfig.obstacleBaseSpawnInterval * 1000).round(),
      'max_wind_force': GameConfig.maxWindForce.round(),
      'powerup_interval_ms':
          (GameConfig.powerUpBaseSpawnInterval * 1000).round(),
      'interstitial_cap_runs': GameConfig.interstitialFrequencyCap,
    });
  }

  Future<void> logRunCompleted({
    required GameMode mode,
    required int score,
    required double distanceMeters,
    required double durationSeconds,
    required int coinsCollected,
    required int nearMisses,
    required int maxCombo,
    required int powerUpsUsed,
    required String biome,
    required String crashCause,
    required bool wasRevived,
    String? replayFingerprint,
  }) {
    return _safeEvent('run_completed', {
      'mode': mode.name,
      'score': score,
      'distance_meters': distanceMeters.round(),
      'duration_seconds': durationSeconds.round(),
      'coins_collected': coinsCollected,
      'near_misses': nearMisses,
      'max_combo': maxCombo,
      'powerups_used': powerUpsUsed,
      'final_biome': biome,
      'crash_cause': crashCause,
      'was_revived': wasRevived ? 1 : 0,
      if (replayFingerprint != null && replayFingerprint.isNotEmpty)
        'replay_fingerprint': replayFingerprint,
    });
  }

  Future<void> logRunAbandoned({
    required GameMode mode,
    required double distanceMeters,
    required double durationSeconds,
    required int score,
    required String reason,
  }) {
    return _safeEvent('run_abandoned', {
      'mode': mode.name,
      'distance_meters': distanceMeters.round(),
      'duration_seconds': durationSeconds.round(),
      'score': score,
      'reason': reason,
    });
  }

  Future<void> logTrialOutcome({
    required int trialId,
    required bool completed,
    required bool timedOut,
    required int stars,
    required double durationSeconds,
    required int coinsCollected,
    required int totalCoins,
  }) {
    return _safeEvent('trial_completed', {
      'trial_id': trialId,
      'completed': completed ? 1 : 0,
      'timed_out': timedOut ? 1 : 0,
      'failure_reason': completed
          ? 'none'
          : timedOut
              ? 'timeout'
              : 'collision',
      'stars': stars,
      'duration_seconds': durationSeconds.round(),
      'coins_collected': coinsCollected,
      'total_coins': totalCoins,
    });
  }

  Future<void> logZenCompleted({
    required double distanceMeters,
    required double durationSeconds,
  }) {
    return _safeEvent('zen_flight_completed', {
      'distance_meters': distanceMeters.round(),
      'duration_seconds': durationSeconds.round(),
    });
  }

  Future<void> logNewHighScore(int score) {
    return _safeEvent('new_high_score', {'score': score});
  }

  // ── Runtime performance ──────────────────────────────────────────────────

  /// One bounded post-run health report joining replay integrity and pool
  /// lifecycle counters. Frame timing remains in [logFramePerformance] so this
  /// event stays useful even when platform timing callbacks are unavailable.
  Future<void> logRuntimeDiagnostics({
    required GameMode mode,
    required String outcome,
    required RuntimeDiagnosticsSnapshot snapshot,
  }) {
    return _safeEvent('game_runtime_diagnostics', {
      'mode': mode.name,
      'outcome': outcome,
      'run_seed': snapshot.runSeed,
      'replay_fingerprint': snapshot.replay.fingerprint,
      'trace_events': snapshot.replay.eventCount,
      'trace_entries': snapshot.replay.recentEntries.length,
      'pool_created': snapshot.poolCreated,
      'pool_discarded': snapshot.poolDiscarded,
      'pool_rejected_releases': snapshot.poolRejectedReleases,
      'pool_peak_in_use': snapshot.poolPeakInUse,
      'active_entities': snapshot.activeEntityCount,
      'difficulty_x100': (snapshot.dynamicDifficulty * 100).round(),
    });
  }

  Future<void> logFramePerformance({
    required GameMode mode,
    required String outcome,
    required int frameCount,
    required double averageFrameMs,
    required double p95FrameMs,
    required double averageBuildMs,
    required double averageRasterMs,
    required int slowFrameCount,
    required int frozenFrameCount,
    int? trialId,
  }) {
    return _safeEvent('game_frame_performance', {
      'mode': mode.name,
      'outcome': outcome,
      'frame_count': frameCount,
      'avg_frame_ms_x10': (averageFrameMs * 10).round(),
      'p95_frame_ms_x10': (p95FrameMs * 10).round(),
      'avg_build_ms_x10': (averageBuildMs * 10).round(),
      'avg_raster_ms_x10': (averageRasterMs * 10).round(),
      'slow_frames': slowFrameCount,
      'frozen_frames': frozenFrameCount,
      if (trialId != null) 'trial_id': trialId,
    });
  }

  // ── Onboarding / navigation funnels ──────────────────────────────────────

  Future<void> logOnboarding({
    required String action,
    String? surface,
    int? page,
    GameMode? mode,
  }) {
    return _safeEvent('onboarding_action', {
      'action': action,
      if (surface != null) 'surface': surface,
      if (page != null) 'page': page,
      if (mode != null) 'mode': mode.name,
    });
  }

  Future<void> logModeSelected(GameMode mode, {required String source}) {
    return _safeEvent('mode_selected', {
      'mode': mode.name,
      'source': source,
    });
  }

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  Future<void> logHangarOpen() => _safeEvent('hangar_opened');

  Future<void> logPlaneUnlocked(String planeName) {
    return _safeEvent('plane_unlocked', {'plane': planeName});
  }

  // ── Economy ──────────────────────────────────────────────────────────────

  Future<void> logEconomyTransaction({
    required String currency,
    required String direction,
    required int amount,
    required int balanceAfter,
    required String reason,
  }) {
    return _safeEvent('economy_transaction', {
      'currency': currency,
      'direction': direction,
      'amount': amount,
      'balance_after': balanceAfter,
      'reason': reason,
    });
  }

  // ── Monetisation funnel ──────────────────────────────────────────────────

  Future<void> logAdRequest({
    required AdPlacement placement,
    required String format,
    required bool ready,
  }) {
    return _safeEvent('ad_requested', {
      'placement': placement.name,
      'ad_format': format,
      'inventory_ready': ready ? 1 : 0,
    });
  }

  Future<void> logAdImpression(AdPlacement placement, {String? format}) {
    return _safeEvent('ad_impression', {
      'placement': placement.name,
      if (format != null) 'ad_format': format,
    });
  }

  Future<void> logAdOutcome({
    required AdPlacement placement,
    required String format,
    required String outcome,
    String? errorCode,
  }) {
    return _safeEvent('ad_outcome', {
      'placement': placement.name,
      'ad_format': format,
      'outcome': outcome,
      if (errorCode != null) 'error_code': errorCode,
    });
  }

  Future<void> logAdRewardEarned(AdPlacement placement) {
    return _safeEvent('ad_reward_earned', {'placement': placement.name});
  }

  Future<void> logIapPurchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    try {
      await _analytics.logPurchase(
        currency: currency,
        value: value,
        items: [
          AnalyticsEventItem(itemId: productId, itemName: productId),
        ],
      );
    } catch (_) {}
  }

  // ── Generic event ────────────────────────────────────────────────────────

  Future<void> logEvent(
    String name, {
    Map<String, Object>? params,
  }) {
    return _safeEvent(name, params);
  }

  // ── Crashlytics ──────────────────────────────────────────────────────────

  Future<void> setUserId(String id) async {
    try {
      await _analytics.setUserId(id: id);
      await FirebaseCrashlytics.instance.setUserIdentifier(id);
    } catch (_) {}
  }

  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    try {
      await FirebaseCrashlytics.instance
          .recordError(exception, stack, fatal: fatal);
    } catch (_) {}
  }
}

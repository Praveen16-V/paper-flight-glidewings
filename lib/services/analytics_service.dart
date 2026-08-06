import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../core/enums/game_enums.dart';

/// Thin wrapper around Firebase Analytics + Crashlytics.
///
/// All event names use snake_case per Firebase convention.
/// Keep event names stable — changing them after launch breaks funnel data.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  // ── Core game loop KPIs ───────────────────────────────────────────────────

  Future<void> logRunStarted() async {
    await _analytics.logEvent(name: 'run_started');
  }

  Future<void> logRunCompleted({
    required int score,
    required double distanceMeters,
    required int coinsCollected,
    required int nearMisses,
    required String biome,
    required bool wasRevived,
  }) async {
    await _analytics.logEvent(
      name: 'run_completed',
      parameters: {
        'score': score,
        'distance_meters': distanceMeters.toInt(),
        'coins_collected': coinsCollected,
        'near_misses': nearMisses,
        'final_biome': biome,
        'was_revived': wasRevived ? 1 : 0,
      },
    );
  }

  Future<void> logNewHighScore(int score) async {
    await _analytics.logEvent(
      name: 'new_high_score',
      parameters: {'score': score},
    );
  }

  // ── Monetisation funnel ───────────────────────────────────────────────────

  Future<void> logAdImpression(AdPlacement placement) async {
    await _analytics.logEvent(
      name: 'ad_impression',
      parameters: {'placement': placement.name},
    );
  }

  Future<void> logAdRewardEarned(AdPlacement placement) async {
    await _analytics.logEvent(
      name: 'ad_reward_earned',
      parameters: {'placement': placement.name},
    );
  }

  Future<void> logIapPurchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    await _analytics.logPurchase(
      currency: currency,
      value: value,
      items: [
        AnalyticsEventItem(itemId: productId, itemName: productId),
      ],
    );
  }

  // ── Navigation / engagement ───────────────────────────────────────────────

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logHangarOpen() async {
    await _analytics.logEvent(name: 'hangar_opened');
  }

  Future<void> logPlaneUnlocked(String planeName) async {
    await _analytics.logEvent(
      name: 'plane_unlocked',
      parameters: {'plane': planeName},
    );
  }

  // ── Generic event ─────────────────────────────────────────────────────────

  Future<void> logEvent(
    String name, {
    Map<String, Object>? params,
  }) async {
    await _analytics.logEvent(name: name, parameters: params);
  }

  // ── Crashlytics ───────────────────────────────────────────────────────────

  Future<void> setUserId(String id) async {
    await _analytics.setUserId(id: id);
    await FirebaseCrashlytics.instance.setUserIdentifier(id);
  }

  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    await FirebaseCrashlytics.instance
        .recordError(exception, stack, fatal: fatal);
  }
}

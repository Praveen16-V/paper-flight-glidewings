import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../core/enums/game_enums.dart';

/// Thin wrapper around Firebase Analytics + Crashlytics.
///
/// All event names use snake_case per Firebase convention.
/// Keep event names stable — changing them after launch breaks funnel data.
///
/// All methods fail soft when Firebase is not configured (local/dev builds).
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool get _ready {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAnalytics? get _analytics {
    if (!_ready) return null;
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> logAppOpen() async {
    try {
      await _analytics?.logAppOpen();
    } catch (e) {
      debugPrint('analytics logAppOpen: $e');
    }
  }

  // ── Core game loop KPIs ───────────────────────────────────────────────────

  Future<void> logRunStarted() async {
    try {
      await _analytics?.logEvent(name: 'run_started');
    } catch (_) {}
  }

  Future<void> logRunCompleted({
    required int score,
    required double distanceMeters,
    required int coinsCollected,
    required int nearMisses,
    required String biome,
    required bool wasRevived,
  }) async {
    try {
      await _analytics?.logEvent(
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
    } catch (_) {}
  }

  Future<void> logNewHighScore(int score) async {
    try {
      await _analytics?.logEvent(
        name: 'new_high_score',
        parameters: {'score': score},
      );
    } catch (_) {}
  }

  // ── Monetisation funnel ───────────────────────────────────────────────────

  Future<void> logAdImpression(AdPlacement placement) async {
    try {
      await _analytics?.logEvent(
        name: 'ad_impression',
        parameters: {'placement': placement.name},
      );
    } catch (_) {}
  }

  Future<void> logAdRewardEarned(AdPlacement placement) async {
    try {
      await _analytics?.logEvent(
        name: 'ad_reward_earned',
        parameters: {'placement': placement.name},
      );
    } catch (_) {}
  }

  Future<void> logIapPurchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    try {
      await _analytics?.logPurchase(
        currency: currency,
        value: value,
        items: [
          AnalyticsEventItem(itemId: productId, itemName: productId),
        ],
      );
    } catch (_) {}
  }

  // ── Navigation / engagement ───────────────────────────────────────────────

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics?.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  Future<void> logHangarOpen() async {
    try {
      await _analytics?.logEvent(name: 'hangar_opened');
    } catch (_) {}
  }

  Future<void> logPlaneUnlocked(String planeName) async {
    try {
      await _analytics?.logEvent(
        name: 'plane_unlocked',
        parameters: {'plane': planeName},
      );
    } catch (_) {}
  }

  // ── Generic event ─────────────────────────────────────────────────────────

  Future<void> logEvent(
    String name, {
    Map<String, Object>? params,
  }) async {
    try {
      await _analytics?.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  // ── Crashlytics ───────────────────────────────────────────────────────────

  Future<void> setUserId(String id) async {
    try {
      await _analytics?.setUserId(id: id);
      if (_ready) {
        await FirebaseCrashlytics.instance.setUserIdentifier(id);
      }
    } catch (_) {}
  }

  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    try {
      if (_ready) {
        await FirebaseCrashlytics.instance
            .recordError(exception, stack, fatal: fatal);
      }
    } catch (_) {}
  }
}

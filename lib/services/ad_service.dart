import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import 'analytics_service.dart';

/// Centralized AdMob lifecycle and frequency-cap owner.
///
/// Rewarded ads are always explicit player choices. Interstitial eligibility is
/// checked against both the honeymoon and run cap, and the caller resets its
/// persisted counter only when this service confirms that an ad was actually
/// shown. This avoids the former bug where a skipped check reset the counter on
/// every game-over and prevented the cap from ever being reached.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static String get _rewardedId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  static String get _interstitialId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _rewardedLoading = false;
  bool _interstitialLoading = false;
  bool _disposed = false;

  /// Call once after Mobile Ads initialization.
  void preload() {
    if (_disposed) return;
    _loadRewarded();
    _loadInterstitial();
  }

  // ── Rewarded ─────────────────────────────────────────────────────────────

  void _loadRewarded() {
    if (_disposed || _rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _rewardedAd = ad;
          _rewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          AnalyticsService.instance.logEvent(
            'ad_inventory_failed',
            params: {
              'ad_format': 'rewarded',
              'error_code': '${error.code}',
            },
          );
          Future<void>.delayed(
            const Duration(seconds: 30),
            _loadRewarded,
          );
        },
      ),
    );
  }

  bool get isRewardedReady => _rewardedAd != null;

  /// Shows a rewarded ad if inventory is ready.
  ///
  /// [onRewarded] runs only after the SDK grants the reward. [onDismissed]
  /// always runs once, including unavailable/failed-to-show outcomes.
  Future<void> showRewarded({
    required AdPlacement placement,
    required VoidCallback onRewarded,
    required VoidCallback onDismissed,
  }) async {
    final ad = _rewardedAd;
    AnalyticsService.instance.logAdRequest(
      placement: placement,
      format: 'rewarded',
      ready: ad != null,
    );

    if (ad == null) {
      AnalyticsService.instance.logAdOutcome(
        placement: placement,
        format: 'rewarded',
        outcome: 'unavailable',
      );
      onDismissed();
      _loadRewarded();
      return;
    }

    // Remove from inventory before showing so rapid double taps cannot present
    // the same native object twice.
    _rewardedAd = null;
    var rewarded = false;
    var callbackCompleted = false;

    void finishDismissal() {
      if (callbackCompleted) return;
      callbackCompleted = true;
      onDismissed();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        AnalyticsService.instance.logAdImpression(
          placement,
          format: 'rewarded',
        );
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        AnalyticsService.instance.logAdOutcome(
          placement: placement,
          format: 'rewarded',
          outcome: rewarded ? 'rewarded_and_dismissed' : 'dismissed',
        );
        _loadRewarded();
        finishDismissal();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        AnalyticsService.instance.logAdOutcome(
          placement: placement,
          format: 'rewarded',
          outcome: 'show_failed',
          errorCode: '${error.code}',
        );
        _loadRewarded();
        finishDismissal();
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (_, reward) {
          if (rewarded) return;
          rewarded = true;
          AnalyticsService.instance.logAdRewardEarned(placement);
          onRewarded();
        },
      );
    } catch (_) {
      ad.dispose();
      AnalyticsService.instance.logAdOutcome(
        placement: placement,
        format: 'rewarded',
        outcome: 'show_exception',
      );
      _loadRewarded();
      finishDismissal();
    }
  }

  // ── Interstitial ─────────────────────────────────────────────────────────

  void _loadInterstitial() {
    if (_disposed || _interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitialAd = ad;
          _interstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          AnalyticsService.instance.logEvent(
            'ad_inventory_failed',
            params: {
              'ad_format': 'interstitial',
              'error_code': '${error.code}',
            },
          );
          Future<void>.delayed(
            const Duration(seconds: 30),
            _loadInterstitial,
          );
        },
      ),
    );
  }

  bool get isInterstitialReady => _interstitialAd != null;

  /// Returns true only after an eligible interstitial was presented and then
  /// dismissed. A cap/honeymoon/inventory skip returns false immediately.
  Future<bool> maybeShowInterstitial({
    required int totalRuns,
    required int runsSinceLastInterstitial,
    required bool adsRemoved,
  }) async {
    final eligible = !adsRemoved &&
        totalRuns >= GameConfig.interstitialHoneymoonRuns &&
        runsSinceLastInterstitial >= GameConfig.interstitialFrequencyCap;
    final ad = _interstitialAd;

    AnalyticsService.instance.logAdRequest(
      placement: AdPlacement.gameOver,
      format: 'interstitial',
      ready: ad != null,
    );

    if (!eligible || ad == null) {
      AnalyticsService.instance.logAdOutcome(
        placement: AdPlacement.gameOver,
        format: 'interstitial',
        outcome: adsRemoved
            ? 'ads_removed'
            : !eligible
                ? 'frequency_capped'
                : 'unavailable',
      );
      if (eligible && ad == null) _loadInterstitial();
      return false;
    }

    _interstitialAd = null;
    final completer = Completer<bool>();
    var wasShown = false;

    void complete(bool value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        wasShown = true;
        AnalyticsService.instance.logAdImpression(
          AdPlacement.gameOver,
          format: 'interstitial',
        );
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        AnalyticsService.instance.logAdOutcome(
          placement: AdPlacement.gameOver,
          format: 'interstitial',
          outcome: 'dismissed',
        );
        _loadInterstitial();
        complete(wasShown);
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        AnalyticsService.instance.logAdOutcome(
          placement: AdPlacement.gameOver,
          format: 'interstitial',
          outcome: 'show_failed',
          errorCode: '${error.code}',
        );
        _loadInterstitial();
        complete(false);
      },
    );

    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      AnalyticsService.instance.logAdOutcome(
        placement: AdPlacement.gameOver,
        format: 'interstitial',
        outcome: 'show_exception',
      );
      _loadInterstitial();
      complete(false);
    }

    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}

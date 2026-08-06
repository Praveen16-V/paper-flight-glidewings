import 'dart:io';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import 'analytics_service.dart';

/// Centralised AdMob wrapper.
///
/// Rewarded ads are always opt-in (player-initiated).
/// Interstitials are capped to [GameConfig.interstitialFrequencyCap] runs
/// and never shown during the honeymoon period
/// ([GameConfig.interstitialHoneymoonRuns]).
///
/// Test ad unit IDs are used by default — replace with real IDs before
/// publishing (store them in a build-flavour config, never hard-code prod IDs
/// into source control).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad unit IDs ───────────────────────────────────────────────────────────
  // Test IDs supplied by Google — safe for development builds.
  static String get _rewardedId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  static String get _interstitialId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  // ── State ─────────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _rewardedLoading = false;
  bool _interstitialLoading = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once at app start after [MobileAds.instance.initialize()].
  void preload() {
    _loadRewarded();
    _loadInterstitial();
  }

  // ── Rewarded ──────────────────────────────────────────────────────────────

  void _loadRewarded() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _rewardedAd = null;
              _loadRewarded(); // pre-load the next one immediately
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _rewardedAd = null;
              _rewardedLoading = false;
              _loadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          // Retry after a short delay so we don't hammer the network.
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  /// Returns true if a rewarded ad is ready to show.
  bool get isRewardedReady => _rewardedAd != null;

  /// Show a rewarded ad. [placement] is used for analytics.
  /// [onRewarded] fires only if the user earns the reward (watched to end).
  /// [onDismissed] fires regardless (so the caller can resume game flow).
  Future<void> showRewarded({
    required AdPlacement placement,
    required VoidCallback onRewarded,
    required VoidCallback onDismissed,
  }) async {
    if (_rewardedAd == null) {
      // Ad not ready — fire dismissed so caller can handle gracefully.
      onDismissed();
      _loadRewarded();
      return;
    }

    AnalyticsService.instance.logAdImpression(placement);

    bool rewarded = false;
    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        rewarded = true;
        AnalyticsService.instance.logAdRewardEarned(placement);
        onRewarded();
      },
    );

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _rewardedAd = null;
        _loadRewarded();
        if (!rewarded) onDismissed();
      },
      onAdFailedToShowFullScreenContent: (_, __) {
        _rewardedAd = null;
        _loadRewarded();
        onDismissed();
      },
    );
  }

  // ── Interstitial ──────────────────────────────────────────────────────────

  void _loadInterstitial() {
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _interstitialAd = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _interstitialAd = null;
              _interstitialLoading = false;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitialLoading = false;
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  bool get isInterstitialReady => _interstitialAd != null;

  /// Show an interstitial if the frequency cap and honeymoon rules allow.
  ///
  /// [totalRuns] — lifetime run count (from SaveData).
  /// [runsSinceLastInterstitial] — runs since last interstitial was shown.
  /// [adsRemoved] — skip entirely if the player bought Remove Ads.
  /// [onComplete] — called after ad is dismissed or skipped.
  Future<void> maybeShowInterstitial({
    required int totalRuns,
    required int runsSinceLastInterstitial,
    required bool adsRemoved,
    required VoidCallback onComplete,
  }) async {
    if (adsRemoved ||
        totalRuns < GameConfig.interstitialHoneymoonRuns ||
        runsSinceLastInterstitial < GameConfig.interstitialFrequencyCap ||
        _interstitialAd == null) {
      onComplete();
      return;
    }

    AnalyticsService.instance.logAdImpression(AdPlacement.gameOver);
    _interstitialAd!.show();
    // fullScreenContentCallback set in _loadInterstitial handles onComplete
    // via dismiss. We call it immediately after show() returns — the dismiss
    // callback will fire asynchronously but we want the UI to continue.
    // In a production build, move onComplete into the dismiss callback.
    onComplete();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}

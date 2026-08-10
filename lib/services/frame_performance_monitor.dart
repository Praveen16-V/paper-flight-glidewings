import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../core/enums/game_enums.dart';
import 'analytics_service.dart';

/// Low-overhead frame-time sampler for real-device gameplay validation.
///
/// Flutter reports build/raster timings in batches. This monitor aggregates all
/// frames and keeps a bounded rolling sample for the p95 calculation, then emits
/// one event when the game screen exits. It is intentionally disabled outside
/// gameplay so menus do not contaminate the device performance cohort.
class FramePerformanceMonitor {
  FramePerformanceMonitor({required this.mode, this.trialId});

  final GameMode mode;
  final int? trialId;

  static const int _maxPercentileSamples = 3000;
  static const double _slowFrameThresholdMs = 16.7;
  static const double _frozenFrameThresholdMs = 100.0;

  final List<double> _frameSamplesMs = <double>[];
  int _sampleCursor = 0;
  int _frameCount = 0;
  int _slowFrameCount = 0;
  int _frozenFrameCount = 0;
  double _totalFrameMs = 0;
  double _totalBuildMs = 0;
  double _totalRasterMs = 0;
  bool _active = false;
  bool _reported = false;

  void start() {
    if (_active || _reported) return;
    _active = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_active) return;
    for (final timing in timings) {
      final frameMs = timing.totalSpan.inMicroseconds / 1000.0;
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;

      _frameCount++;
      _totalFrameMs += frameMs;
      _totalBuildMs += buildMs;
      _totalRasterMs += rasterMs;
      if (frameMs > _slowFrameThresholdMs) _slowFrameCount++;
      if (frameMs > _frozenFrameThresholdMs) _frozenFrameCount++;

      if (_frameSamplesMs.length < _maxPercentileSamples) {
        _frameSamplesMs.add(frameMs);
      } else {
        _frameSamplesMs[_sampleCursor] = frameMs;
        _sampleCursor = (_sampleCursor + 1) % _maxPercentileSamples;
      }
    }
  }

  /// Stops sampling and sends exactly one aggregate event.
  void stop({required String outcome}) {
    if (_reported) return;
    _reported = true;
    if (_active) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _active = false;
    }
    if (_frameCount == 0) return;

    final sorted = List<double>.from(_frameSamplesMs)..sort();
    final p95Index = ((sorted.length - 1) * 0.95).round();
    final p95 = sorted[p95Index.clamp(0, sorted.length - 1).toInt()];

    unawaited(
      AnalyticsService.instance.logFramePerformance(
        mode: mode,
        trialId: trialId,
        outcome: outcome,
        frameCount: _frameCount,
        averageFrameMs: _totalFrameMs / _frameCount,
        p95FrameMs: p95,
        averageBuildMs: _totalBuildMs / _frameCount,
        averageRasterMs: _totalRasterMs / _frameCount,
        slowFrameCount: _slowFrameCount,
        frozenFrameCount: _frozenFrameCount,
      ),
    );
  }
}

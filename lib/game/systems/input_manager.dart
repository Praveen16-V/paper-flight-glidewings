import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

/// Owns all player input and exposes clean, filtered values each frame.
///
/// Supports three control schemes:
///   [ControlScheme.tilt]       — accelerometer/gyro X axis → horizontal
///   [ControlScheme.touchZones] — left half / right half touch → horizontal
///   [ControlScheme.drag]       — one-finger direct drag: horizontal pointer X → steer
///
/// Vertical: hold anywhere = lift, release = glide (bool). In drag mode the
/// vertical axis is still hold-based so one finger can both steer (X) and
/// climb (press) without a second gesture.
///
/// Paper-snap burst: triggered by any of
///   • double-tap (legacy, kept for compat)
///   • quick flick-up gesture (pointer Y moves up quickly)
///   • dedicated BOOST button (HUD calls [requestSnapFromButton])
/// Each consumes one of [snapMaxCharges] charges that recharge over distance.
class InputManager extends Component {
  InputManager({required this.game});

  final PaperFlightGame game;

  // ── Outputs (read by PlaneComponent each frame) ───────────────────────────

  /// True while the player is pressing down.
  bool get isHolding => _isHolding;

  /// Horizontal intent [-1, 1]. Negative = left, positive = right.
  double get horizontalInput => _filteredTilt;

  /// True if a paper-snap burst was consumed this frame.
  bool consumeSnap() {
    if (_snapQueued && _snapCharges > 0) {
      _snapCharges--;
      _snapQueued = false;
      // Keep any fractional progress toward next charge if still below max,
      // but if we just dropped from max, start from 0.
      if (_snapCharges == GameConfig.snapMaxCharges - 1 && _snapRechargeProgress == 0) {
        // first depletion, nothing to preserve
      }
      return true;
    }
    return false;
  }

  /// Called by HUD BOOST button. Returns true if a charge was queued.
  bool requestSnapFromButton() {
    if (_snapCharges > 0) {
      _snapQueued = true;
      if (gameRefOrNull != null) {
        HapticFeedback.lightImpact();
      }
      return true;
    } else {
      HapticFeedback.selectionClick();
      return false;
    }
  }

  /// Called when a flick-up gesture is detected.
  bool _queueSnapFromGesture() {
    if (_snapCharges > 0 && !_snapQueued) {
      _snapQueued = true;
      HapticFeedback.mediumImpact();
      return true;
    }
    return false;
  }

  int get snapCharges => _snapCharges;
  double get snapRechargeProgress => _snapRechargeProgress; // 0..1 toward next charge
  double get snapRechargeFraction {
    if (_snapCharges >= GameConfig.snapMaxCharges) return 1.0;
    return _snapRechargeProgress.clamp(0.0, 1.0);
  }

  bool get hasSnapQueued => _snapQueued;

  // ── Internal State ─────────────────────────────────────────────────────────

  bool _isHolding = false;
  double _rawTilt = 0.0;        // raw accelerometer X (g units)
  double _filteredTilt = 0.0;   // smoothed, sensitivity-scaled, [-1,1]
  int _snapCharges = GameConfig.snapMaxCharges;
  bool _snapQueued = false;
  double _snapRechargeProgress = 0.0;

  // Touch-zone tracking for alt control scheme.
  bool _touchLeft = false;
  bool _touchRight = false;

  // Direct drag tracking.
  Vector2? _dragPointerPos;  // current finger position while holding
  Vector2? _dragStartPos;
  DateTime? _dragStartTime;

  // Double-tap detection (legacy).
  DateTime? _lastTapTime;
  static const Duration _doubleTapWindow = Duration(milliseconds: 250);

  // Tilt calibration baseline (set on first active run frame).
  double _tiltBaseline = 0.0;
  bool _tiltCalibrated = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;

  ControlScheme _controlScheme = ControlScheme.tilt;

  PaperFlightGame? get gameRefOrNull {
    try {
      return game;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> onLoad() async {
    _startSensorStream();
    await super.onLoad();
  }

  @override
  void onRemove() {
    _accelSub?.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    _updateHorizontalFromScheme();
    _tickSnapRecharge(dt);
  }

  // ── Settings sync ─────────────────────────────────────────────────────────

  void updateControlScheme(ControlScheme scheme) {
    _controlScheme = scheme;
    // Reset transient steering state when switching schemes.
    _filteredTilt = 0.0;
    _touchLeft = false;
    _touchRight = false;
    if (scheme != ControlScheme.drag) {
      _dragPointerPos = null;
      _dragStartPos = null;
      _dragStartTime = null;
    }
  }

  void updateSensitivity(double value) {
    _sensitivity = value.clamp(0.3, 2.0);
  }

  ControlScheme get currentScheme => _controlScheme;

  // ── Tap / Drag Events (forwarded from PaperFlightGame) ────────────────────

  void onTapDown(Vector2 position) {
    _isHolding = true;
    _dragPointerPos = position.clone();
    _dragStartPos = position.clone();
    _dragStartTime = DateTime.now();
    _handleTouchZone(position, true);
    _checkDoubleTap();
  }

  void onTapUp(Vector2 position) {
    _isHolding = false;
    _handleTouchZone(position, false);
    _checkFlickUp(position);
    // keep last pointer for a frame so drag decay is smooth
  }

  void onDragStart(Vector2 position) {
    _isHolding = true;
    _dragPointerPos = position.clone();
    _dragStartPos = position.clone();
    _dragStartTime = DateTime.now();
    _handleTouchZone(position, true);
  }

  void onDragUpdate(Vector2 position) {
    _isHolding = true;
    _dragPointerPos = position.clone();
    _handleTouchZone(position, true);
  }

  void onDragEnd() {
    final endPos = _dragPointerPos?.clone();
    _isHolding = false;
    _touchLeft = false;
    _touchRight = false;
    if (endPos != null && _dragStartPos != null) {
      _checkFlickUp(endPos);
    }
    // Don't immediately clear _dragPointerPos — let it decay in _updateHorizontalFromScheme
  }

  void onDragCancel() => onDragEnd();

  void calibrateTilt() {
    _tiltBaseline = _rawTilt;
    _tiltCalibrated = true;
  }

  void reset() {
    _isHolding = false;
    _filteredTilt = 0.0;
    _rawTilt = 0.0;
    _snapCharges = GameConfig.snapMaxCharges;
    _snapQueued = false;
    _snapRechargeProgress = 0.0;
    _touchLeft = false;
    _touchRight = false;
    _dragPointerPos = null;
    _dragStartPos = null;
    _dragStartTime = null;
    _tiltCalibrated = false;
  }

  // ── Sensor Stream ─────────────────────────────────────────────────────────

  double _sensitivity = GameConfig.defaultTiltSensitivity;

  /// Current tilt sensitivity — read by PlaneComponent each frame.
  double get currentSensitivity => _sensitivity;

  void _startSensorStream() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      _rawTilt = -event.x;
    }, onError: (_) {
      _rawTilt = 0.0;
    });
  }

  void _updateHorizontalFromScheme() {
    final scheme = _controlScheme;

    if (scheme == ControlScheme.touchZones) {
      if (_touchLeft) {
        _filteredTilt = MathUtils.lowPass(_filteredTilt, -1.0, 0.15);
      } else if (_touchRight) {
        _filteredTilt = MathUtils.lowPass(_filteredTilt, 1.0, 0.15);
      } else {
        _filteredTilt = MathUtils.lowPass(_filteredTilt, 0.0, 0.12);
      }
      return;
    }

    if (scheme == ControlScheme.drag) {
      if (_isHolding && _dragPointerPos != null) {
        // Map pointer X to [-1,1]. Dead-zone around centre.
        final raw = (_dragPointerPos!.x - GameConfig.designWidth / 2) /
            (GameConfig.designWidth / 2);
        final deadZoneNorm = GameConfig.dragDeadZone / (GameConfig.designWidth / 2);
        double target = raw.clamp(-1.0, 1.0);
        if (target.abs() < deadZoneNorm) target = 0.0;
        // Apply sensitivity scaling for drag as well.
        target = (target * _sensitivity).clamp(-1.0, 1.0);
        _filteredTilt = MathUtils.lowPass(
          _filteredTilt,
          target,
          GameConfig.dragSmoothingAlpha,
        );
      } else {
        // Decay to centre when finger released — plane coasts.
        _filteredTilt = MathUtils.lowPass(_filteredTilt, 0.0, 0.14);
      }
      return;
    }

    // Tilt scheme.
    if (!_tiltCalibrated) {
      _tiltBaseline = _rawTilt;
      _tiltCalibrated = true;
    }

    final adjusted = (_rawTilt - _tiltBaseline) * _sensitivity;
    final clamped = adjusted.clamp(-1.0, 1.0);
    const deadZone = 0.08;
    final deadzoned = clamped.abs() < deadZone ? 0.0 : clamped;

    _filteredTilt = MathUtils.lowPass(
      _filteredTilt,
      deadzoned,
      GameConfig.tiltLowPassAlpha,
    );
  }

  void _handleTouchZone(Vector2 position, bool active) {
    if (_controlScheme != ControlScheme.touchZones) return;
    final midX = GameConfig.designWidth / 2;
    if (position.x < midX) {
      _touchLeft = active;
      if (active) _touchRight = false;
    } else {
      _touchRight = active;
      if (active) _touchLeft = false;
    }
  }

  void _checkDoubleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow) {
      // Queue snap without interrupting hold state.
      if (_snapCharges > 0) _snapQueued = true;
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
    }
  }

  void _checkFlickUp(Vector2 endPos) {
    if (_dragStartPos == null || _dragStartTime == null) return;
    final dy = endPos.y - _dragStartPos!.y; // negative = upward
    final dtMs = DateTime.now().difference(_dragStartTime!).inMilliseconds.toDouble();
    if (dtMs <= 0 || dtMs > GameConfig.snapFlickMaxDurationMs) return;
    if (dy > -GameConfig.snapFlickMinDistance) return; // not enough upward travel
    final velocity = -dy / (dtMs / 1000.0); // px/s upward positive
    if (velocity < GameConfig.snapFlickMinVelocity) return;
    _queueSnapFromGesture();
  }

  static double get _snapRechargePerMeter => 1.0 / GameConfig.snapRechargeMeters;

  void _tickSnapRecharge(double dt) {
    if (_snapCharges >= GameConfig.snapMaxCharges) {
      _snapRechargeProgress = 0.0;
      return;
    }
    // Recharge based on scroll progress (px → approximate meters via /10 internally,
    // but we keep original faster feel: px per second / rechargeMeters).
    // Use effective scroll distance this frame.
    _snapRechargeProgress += game.scrollSpeed * dt * _snapRechargePerMeter;
    if (_snapRechargeProgress >= 1.0) {
      _snapCharges = (_snapCharges + 1).clamp(0, GameConfig.snapMaxCharges);
      _snapRechargeProgress = 0.0;
    }
  }
}

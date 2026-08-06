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
///   [ControlScheme.joystick]   — floating virtual joystick: the stick appears
///                                where the thumb lands and deflects to steer
///
/// Vertical: hold anywhere = lift, release = glide (bool). In joystick mode the
/// vertical axis is still hold-based so one thumb can both steer (X) and climb
/// (press) without a second gesture.
///
/// Gesture power-up action: the double-tap and flick-up gestures are generic
/// triggers — the game decides what they fire (the equipped plane's signature
/// power-up). The dedicated BOOST button ([requestSnapFromButton]) always
/// fires the charge-based paper-snap burst.
class InputManager extends Component {
  InputManager({required this.game});

  final PaperFlightGame game;

  // ── Outputs (read by PlaneComponent each frame) ───────────────────────────

  /// True while the player is pressing down.
  bool get isHolding => _isHolding;

  /// Horizontal intent [-1, 1]. Negative = left, positive = right.
  double get horizontalInput => _filteredTilt;

  // ── Virtual joystick readouts (for the on-screen visual) ─────────────────

  /// True while the floating joystick is being held.
  bool get joystickActive => _joystickActive;

  /// World position of the joystick base ring (design coordinates).
  Vector2 get joystickBasePosition => _joystickBase ?? Vector2.zero();

  /// Knob displacement from the base, clamped to the stick radius
  /// (design coordinates) — used to draw the knob.
  Vector2 get joystickKnobOffset {
    final delta = _joystickDelta;
    if (delta == null) return Vector2.zero();
    final radius = GameConfig.joystickRadius;
    if (delta.length <= radius) return delta.clone();
    return delta.normalized() * radius;
  }

  // ── Touch-zone readouts (for the on-screen zone-guide visual) ────────────

  /// True while the left half of the screen is being pressed
  /// (touch-zones scheme).
  bool get touchZoneLeft => _touchLeft;

  /// True while the right half of the screen is being pressed
  /// (touch-zones scheme).
  bool get touchZoneRight => _touchRight;

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

  /// True if a gesture power-up action was queued and is now consumed.
  /// The game polls this each frame and fires the equipped plane's signature
  /// power-up (Dart: BOOST burst, Glider: Magnet, Stunt Fold: Ghost).
  bool consumeGestureAction() {
    if (_gestureActionQueued) {
      _gestureActionQueued = false;
      return true;
    }
    return false;
  }

  /// Called when a flick-up gesture or double-tap is detected. Only queues
  /// the generic action when the "flick to use power-up" setting is enabled.
  bool _queueGestureAction() {
    if (!_gesturePowerUpEnabled || _gestureActionQueued) return false;
    _gestureActionQueued = true;
    HapticFeedback.mediumImpact();
    return true;
  }

  /// Whether the flick/double-tap gesture may fire power-ups. Mirrors the
  /// "flick to use power-up" setting; when off, gestures do nothing.
  void updateGesturePowerUp(bool enabled) {
    _gesturePowerUpEnabled = enabled;
    if (!enabled) _gestureActionQueued = false;
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

  // Generic gesture → power-up action (flick-up / double-tap).
  bool _gestureActionQueued = false;
  bool _gesturePowerUpEnabled = true;

  // Touch-zone tracking for alt control scheme.
  bool _touchLeft = false;
  bool _touchRight = false;

  // Floating virtual joystick tracking.
  bool _joystickActive = false;      // thumb is down on the stick
  Vector2? _joystickBase;            // where the stick appeared (pointer down)
  Vector2? _joystickDelta;           // pointer offset from base (unclamped)
  DateTime? _joystickStartTime;      // for flick-up snap detection

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
    if (scheme != ControlScheme.joystick) {
      _joystickActive = false;
      _joystickBase = null;
      _joystickDelta = null;
      _joystickStartTime = null;
    }
  }

  void updateSensitivity(double value) {
    _sensitivity = value.clamp(0.3, 2.0);
  }

  ControlScheme get currentScheme => _controlScheme;

  // ── Tap / Drag Events (forwarded from PaperFlightGame) ────────────────────

  void onTapDown(Vector2 position) {
    _isHolding = true;
    _joystickActive = true;
    _joystickBase = position.clone();
    _joystickDelta = Vector2.zero();
    _joystickStartTime = DateTime.now();
    _handleTouchZone(position, true);
    _checkDoubleTap();
  }

  void onTapUp(Vector2 position) {
    _isHolding = false;
    _joystickActive = false;
    _handleTouchZone(position, false);
    _checkFlickUp(position);
    // Keep the stick position for a frame so steering decays smoothly.
  }

  void onDragStart(Vector2 position) {
    _isHolding = true;
    _joystickActive = true;
    _joystickBase = position.clone();
    _joystickDelta = Vector2.zero();
    _joystickStartTime = DateTime.now();
    _handleTouchZone(position, true);
  }

  void onDragUpdate(Vector2 position) {
    _isHolding = true;
    if (_joystickBase != null) {
      _joystickDelta = position - _joystickBase!;
    } else {
      _joystickBase = position.clone();
      _joystickDelta = Vector2.zero();
    }
    _handleTouchZone(position, true);
  }

  void onDragEnd() {
    final endPos = _joystickBase != null && _joystickDelta != null
        ? _joystickBase! + _joystickDelta!
        : null;
    _isHolding = false;
    _joystickActive = false;
    _touchLeft = false;
    _touchRight = false;
    if (endPos != null && _joystickBase != null) {
      _checkFlickUp(endPos);
    }
    // Don't immediately clear the stick — let steering decay in _updateHorizontalFromScheme
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
    _gestureActionQueued = false;
    _touchLeft = false;
    _touchRight = false;
    _joystickActive = false;
    _joystickBase = null;
    _joystickDelta = null;
    _joystickStartTime = null;
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

    if (scheme == ControlScheme.joystick) {
      if (_joystickActive && _joystickDelta != null) {
        // Stick deflection maps to [-1,1] with a dead zone around centre —
        // steering is relative to where the thumb landed, not the screen.
        final raw = _joystickDelta!.x / GameConfig.joystickRadius;
        final deadZoneNorm = GameConfig.joystickDeadZone / GameConfig.joystickRadius;
        double target = raw.clamp(-1.0, 1.0);
        if (target.abs() < deadZoneNorm) target = 0.0;
        // Apply sensitivity scaling for the joystick as well.
        target = (target * _sensitivity).clamp(-1.0, 1.0);
        _filteredTilt = MathUtils.lowPass(
          _filteredTilt,
          target,
          GameConfig.joystickSmoothingAlpha,
        );
      } else {
        // Decay to centre when the stick is released — plane coasts.
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
      // Queue the generic power-up action without interrupting hold state.
      _queueGestureAction();
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
    }
  }

  void _checkFlickUp(Vector2 endPos) {
    if (_joystickBase == null || _joystickStartTime == null) return;
    final dy = endPos.y - _joystickBase!.y; // negative = upward
    final dtMs = DateTime.now().difference(_joystickStartTime!).inMilliseconds.toDouble();
    if (dtMs <= 0 || dtMs > GameConfig.snapFlickMaxDurationMs) return;
    if (dy > -GameConfig.snapFlickMinDistance) return; // not enough upward travel
    final velocity = -dy / (dtMs / 1000.0); // px/s upward positive
    if (velocity < GameConfig.snapFlickMinVelocity) return;
    _queueGestureAction();
  }

  static double get _snapRechargePerMeter => 1.0 / GameConfig.snapRechargeMeters;

  void _tickSnapRecharge(double dt) {
    if (_snapCharges >= GameConfig.snapMaxCharges) {
      _snapRechargeProgress = 0.0;
      return;
    }
    // Stunt Fold recharges twice as fast (Task 7).
    double multiplier = 1.0;
    try {
      if (game.plane.planeType == PlaneType.stuntFold) {
        multiplier = GameConfig.stuntSnapRechargeMultiplier;
      }
    } catch (_) {}
    // Recharge based on scroll progress (px → approximate meters via /10 internally,
    // but we keep original faster feel: px per second / rechargeMeters).
    // Use effective scroll distance this frame.
    _snapRechargeProgress += game.scrollSpeed * dt * _snapRechargePerMeter * multiplier;
    if (_snapRechargeProgress >= 1.0) {
      _snapCharges = (_snapCharges + 1).clamp(0, GameConfig.snapMaxCharges);
      _snapRechargeProgress = 0.0;
    }
  }
}

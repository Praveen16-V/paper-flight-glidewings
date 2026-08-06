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
/// Supports two control schemes:
///   [ControlScheme.tilt]       — accelerometer/gyro X axis → horizontal
///   [ControlScheme.touchZones] — left half / right half touch → horizontal
///
/// Vertical: hold anywhere = lift, release = glide (bool).
/// Double-tap: paper-snap burst (counted, recharges over distance).
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
    if (_snapAvailable && _snapCharges > 0) {
      _snapCharges--;
      _snapAvailable = false;
      return true;
    }
    return false;
  }

  int get snapCharges => _snapCharges;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _isHolding = false;
  double _rawTilt = 0.0;        // raw accelerometer X (g units)
  double _filteredTilt = 0.0;   // smoothed, sensitivity-scaled, [-1,1]
  int _snapCharges = 2;
  bool _snapAvailable = false;
  double _snapRechargeProgress = 0.0;

  // Touch-zone tracking for alt control scheme.
  bool _touchLeft = false;
  bool _touchRight = false;

  // Double-tap detection.
  DateTime? _lastTapTime;
  static const Duration _doubleTapWindow = Duration(milliseconds: 250);

  // Tilt calibration baseline (set on first active run frame).
  double _tiltBaseline = 0.0;
  bool _tiltCalibrated = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;

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
    // Sensitivity is cached in _sensitivity and updated via updateSensitivity().
    // No per-frame provider read needed.
    _updateHorizontalFromScheme();
    _tickSnapRecharge(dt);
  }

  // ── Tap Events (forwarded from PaperFlightGame) ────────────────────────────

  void onTapDown(Vector2 position) {
    _isHolding = true;
    _handleTouchZone(position, true);
    _checkDoubleTap();
  }

  void onTapUp(Vector2 position) {
    _isHolding = false;
    _handleTouchZone(position, false);
  }

  void onDragStart(Vector2 position) {
    _isHolding = true;
    _handleTouchZone(position, true);
  }

  void onDragEnd() {
    _isHolding = false;
    _touchLeft = false;
    _touchRight = false;
  }

  void calibrateTilt() {
    _tiltBaseline = _rawTilt;
    _tiltCalibrated = true;
  }

  void reset() {
    _isHolding = false;
    _filteredTilt = 0.0;
    _rawTilt = 0.0;
    _snapCharges = 2;
    _snapAvailable = false;
    _snapRechargeProgress = 0.0;
    _touchLeft = false;
    _touchRight = false;
    _tiltCalibrated = false;
  }

  // ── Sensor Stream ─────────────────────────────────────────────────────────

  double _sensitivity = GameConfig.defaultTiltSensitivity;

  /// Current tilt sensitivity — read by PlaneComponent each frame.
  double get currentSensitivity => _sensitivity;

  void updateSensitivity(double value) {
    _sensitivity = value.clamp(0.3, 2.0);
  }

  void _startSensorStream() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      // Accelerometer X: positive = tilted right (screen right = positive Y
      // in Android coords when portrait). We negate to match screen space.
      _rawTilt = -event.x;
    }, onError: (_) {
      // Sensor unavailable — fall back to touch zones gracefully.
      _rawTilt = 0.0;
    });
  }

  void _updateHorizontalFromScheme() {
    final scheme = _currentControlScheme();

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

    // Tilt scheme.
    if (!_tiltCalibrated) {
      _tiltBaseline = _rawTilt;
      _tiltCalibrated = true;
    }

    final adjusted = (_rawTilt - _tiltBaseline) * _sensitivity;
    // Clamp to [-1, 1] dead-zone aware.
    final deadZone = 0.08;
    final clamped = adjusted.clamp(-1.0, 1.0);
    final deadzoned = clamped.abs() < deadZone ? 0.0 : clamped;

    _filteredTilt = MathUtils.lowPass(
      _filteredTilt,
      deadzoned,
      GameConfig.tiltLowPassAlpha,
    );
  }

  ControlScheme _currentControlScheme() {
    // Read from settings — cached, not per-frame Riverpod read.
    // In a full build, cache invalidation happens via a ChangeNotifier or
    // direct method call from SettingsNotifier. For MVP, default to tilt.
    return ControlScheme.tilt;
  }

  void _handleTouchZone(Vector2 position, bool active) {
    if (_currentControlScheme() != ControlScheme.touchZones) return;
    final midX = GameConfig.designWidth / 2;
    if (position.x < midX) {
      _touchLeft = active;
    } else {
      _touchRight = active;
    }
  }

  void _checkDoubleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow) {
      _snapAvailable = true;
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
    }
  }

  static const double _snapRechargePerMeter = 1.0 / 200.0; // 1 charge per 200m

  void _tickSnapRecharge(double dt) {
    if (_snapCharges >= 2) return;
    _snapRechargeProgress += game.scrollSpeed * dt * _snapRechargePerMeter;
    if (_snapRechargeProgress >= 1.0) {
      _snapCharges = (_snapCharges + 1).clamp(0, 2);
      _snapRechargeProgress = 0.0;
    }
  }
}

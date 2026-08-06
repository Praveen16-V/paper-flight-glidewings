import 'dart:async';

import 'package:flame/components.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/game_config.dart';
import '../../core/enums/game_enums.dart';
import '../../core/utils/math_utils.dart';
import '../paper_flight_game.dart';

/// Owns all player input and exposes clean, filtered values each frame.
///
/// Supports two control schemes:
///   [ControlScheme.tilt]       — accelerometer X axis → horizontal
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

  /// Current control scheme (cached from settings).
  ControlScheme get controlScheme => _controlScheme;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _isHolding = false;
  double _rawTilt = 0.0;
  double _filteredTilt = 0.0;
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

  double _sensitivity = GameConfig.defaultTiltSensitivity;
  ControlScheme _controlScheme = ControlScheme.tilt;

  /// Current tilt sensitivity — read by PlaneComponent each frame.
  double get currentSensitivity => _sensitivity;

  void updateSensitivity(double value) {
    _sensitivity = value.clamp(0.3, 2.0);
  }

  void updateControlScheme(ControlScheme scheme) {
    _controlScheme = scheme;
    // Clear residual tilt when switching schemes.
    _filteredTilt = 0.0;
    _touchLeft = false;
    _touchRight = false;
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

  void onDragUpdate(Vector2 position) {
    if (_controlScheme == ControlScheme.touchZones) {
      // Track finger as it crosses the midline.
      _touchLeft = position.x < GameConfig.designWidth / 2;
      _touchRight = !_touchLeft;
    }
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

  void _startSensorStream() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((event) {
        // Accelerometer X: when phone is portrait, tilting right produces
        // positive X in device coords. Negate so right-tilt → positive screen X.
        _rawTilt = -event.x;
      }, onError: (_) {
        // Sensor unavailable — fall back to touch zones gracefully.
        _rawTilt = 0.0;
      });
    } catch (_) {
      _rawTilt = 0.0;
    }
  }

  void _updateHorizontalFromScheme() {
    if (_controlScheme == ControlScheme.touchZones) {
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
    // Dead-zone so resting posture doesn't drift.
    const deadZone = 0.08;
    final clamped = adjusted.clamp(-1.0, 1.0);
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
      _snapAvailable = true;
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
    }
  }

  static const double _snapRechargePerMeter = 1.0 / 200.0; // 1 charge per 200m

  void _tickSnapRecharge(double dt) {
    if (_snapCharges >= 2) return;
    // Recharge based on distance covered (scrollSpeed × dt / 10 ≈ meters).
    final metersThisFrame = game.scrollSpeed * dt / 10.0;
    _snapRechargeProgress += metersThisFrame * _snapRechargePerMeter;
    if (_snapRechargeProgress >= 1.0) {
      _snapCharges = (_snapCharges + 1).clamp(0, 2);
      _snapRechargeProgress = 0.0;
    }
  }
}

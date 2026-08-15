import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../../core/constants/game_config.dart';

/// Result of sampling a pilot's orbit around a [ThermalColumnComponent].
class ThermalSurfUpdate {
  const ThermalSurfUpdate({
    required this.liftMultiplier,
    required this.progress,
    required this.completedOrbit,
    required this.bonusActive,
  });

  const ThermalSurfUpdate.idle()
      : liftMultiplier = 1.0,
        progress = 0.0,
        completedOrbit = false,
        bonusActive = false;

  /// Multiplier to apply to this column's lift for the current frame.
  final double liftMultiplier;

  /// Progress around the current orbit, 0..1.
  final double progress;

  /// True for the one frame on which a full circle was completed.
  final bool completedOrbit;

  /// True while the temporary completed-circle lift bonus is active.
  final bool bonusActive;
}

/// A local, visible updraft rather than an invisible full-width lane.
///
/// The component owns both its rising paper-particle presentation and the
/// geometric orbit tracker used for thermal surfing. It deliberately has no
/// collision hitbox: entering or leaving a column is a smooth air-force sample,
/// not a hard gameplay boundary.
class ThermalColumnComponent extends PositionComponent {
  ThermalColumnComponent({
    required this.laneIndex,
    required int particleSeed,
  })  : _rng = math.Random(particleSeed),
        super(
          position: Vector2.zero(),
          size: Vector2(GameConfig.designWidth, GameConfig.designHeight),
          anchor: Anchor.topLeft,
        );

  final int laneIndex;
  final math.Random _rng;
  final List<_ThermalParticle> _particles = [];

  /// Rendering switch kept separate from [_active] so a dissipating column can
  /// finish its visual fade before it is hidden.
  bool visible = false;

  bool _active = false;
  bool get isActive => _active;

  double _centerX = GameConfig.designWidth * .5;
  double get centerX => _centerX;

  double _radius = GameConfig.thermalColumnMinRadius;
  double get radius => _radius;

  double _currentLift = 0;
  double get currentLift => _currentLift;
  double _targetLift = 0;
  double _time = 0;

  // Thermal surfing / ellipse-orbit state.
  double? _lastOrbitAngle;
  double _orbitRadians = 0;
  int _orbitDirection = 0;
  double _bonusTimer = 0;

  double get surfProgress =>
      (_orbitRadians / GameConfig.thermalSurfRequiredRadians)
          .clamp(0.0, 1.0)
          .toDouble();
  bool get surfBonusActive => _bonusTimer > 0;

  /// Starts a freshly located column. [lift] eases in, avoiding a one-frame
  /// vertical kick when a wind lane transitions into a thermal.
  void activate({
    required double centerX,
    required double radius,
    required double lift,
  }) {
    _active = true;
    visible = true;
    _centerX = centerX;
    _radius = radius;
    _currentLift = 0;
    _targetLift = lift;
    _time = 0;
    resetPilotOrbit(clearBonus: true);
    _seedParticles();
  }

  /// Keeps a live column aligned with its current lane's lift strength.
  void refresh(double lift) {
    if (!_active) return;
    _targetLift = lift;
  }

  /// Lets the column dissipate naturally after its source lane is no longer
  /// thermal. The fade maintains visual/physics continuity during noisy wind
  /// transitions instead of blinking the player out of an updraft.
  void fadeOut() {
    if (!_active) return;
    _targetLift = 0;
  }

  void deactivate() {
    _active = false;
    visible = false;
    _currentLift = 0;
    _targetLift = 0;
    resetPilotOrbit(clearBonus: true);
  }

  /// Smooth horizontal influence within the column, 0 at the edge and 1 in the
  /// core. It is public so the manager and tests share exactly one boundary.
  double influenceAt(Vector2 pilotPosition) {
    if (!_active || _currentLift < GameConfig.thermalColumnMinimumLift) {
      return 0.0;
    }
    final normalizedDistance = (pilotPosition.x - _centerX).abs() / _radius;
    if (normalizedDistance >= 1.0) return 0.0;
    final edge = 1.0 - normalizedDistance;
    return edge * edge * (3.0 - 2.0 * edge);
  }

  /// Updraft lift at [pilotPosition], after the local horizontal falloff.
  double liftAt(Vector2 pilotPosition) =>
      _currentLift * influenceAt(pilotPosition);

  /// Records the pilot's path around this thermal's core and returns the lift
  /// boost for the frame. A full, directionally consistent loop earns a
  /// temporary [GameConfig.thermalSurfLiftMultiplier] rather than a passive
  /// "stand in the lane" reward.
  ThermalSurfUpdate trackPilot(Vector2 pilotPosition, double dt) {
    if (dt <= 0) return _currentSurfUpdate();
    final influence = influenceAt(pilotPosition);
    if (influence < GameConfig.thermalSurfMinimumInfluence) {
      resetPilotOrbit();
      return _currentSurfUpdate();
    }

    final dx = (pilotPosition.x - _centerX) /
        (_radius * GameConfig.thermalSurfOrbitHorizontalRadiusMultiplier);
    final dy = (pilotPosition.y - _coreY) /
        GameConfig.thermalSurfOrbitVerticalRadius;
    final orbitRadius = math.sqrt(dx * dx + dy * dy);
    if (orbitRadius < GameConfig.thermalSurfMinOrbitRadius ||
        orbitRadius > GameConfig.thermalSurfMaxOrbitRadius) {
      resetPilotOrbit();
      return _currentSurfUpdate();
    }

    final angle = math.atan2(dy, dx);
    var completedOrbit = false;
    final previous = _lastOrbitAngle;
    if (previous != null) {
      final delta = _shortestAngle(angle - previous);
      final deltaMagnitude = delta.abs();

      // Ignore a stationary/noisy sample, but discard a teleport-like jump so
      // a revive or abrupt ceiling bounce cannot fake an orbit completion.
      if (deltaMagnitude > 0.002 && deltaMagnitude < 0.62) {
        final direction = delta > 0 ? 1 : -1;
        if (_orbitDirection == 0 || direction == _orbitDirection) {
          _orbitDirection = direction;
          _orbitRadians += deltaMagnitude;
        } else {
          // Changing direction bleeds accumulated progress rather than
          // erasing it on one tiny correction; sustained circling still wins.
          _orbitRadians =
              math.max(0.0, _orbitRadians - deltaMagnitude * .8).toDouble();
          _orbitDirection = direction;
        }

        if (_orbitRadians >= GameConfig.thermalSurfRequiredRadians) {
          _orbitRadians = 0;
          _orbitDirection = 0;
          _bonusTimer = GameConfig.thermalSurfBonusDuration;
          completedOrbit = true;
        }
      }
    }
    _lastOrbitAngle = angle;

    final current = _currentSurfUpdate();
    return ThermalSurfUpdate(
      liftMultiplier: current.liftMultiplier,
      progress: current.progress,
      completedOrbit: completedOrbit,
      bonusActive: current.bonusActive,
    );
  }

  void resetPilotOrbit({bool clearBonus = false}) {
    _lastOrbitAngle = null;
    _orbitRadians = 0;
    _orbitDirection = 0;
    if (clearBonus) _bonusTimer = 0;
  }

  @override
  void update(double dt) {
    if (!_active) return;

    _time += dt;
    final response = _targetLift > _currentLift
        ? GameConfig.thermalColumnFadeInRate
        : GameConfig.thermalColumnFadeOutRate;
    final blend = (response * dt).clamp(0.0, 1.0).toDouble();
    _currentLift += (_targetLift - _currentLift) * blend;
    if (_bonusTimer > 0) {
      _bonusTimer = math.max(0.0, _bonusTimer - dt).toDouble();
    }

    for (final particle in _particles) {
      particle.y -= particle.speed * dt;
      particle.xWobble += dt * particle.wobbleSpeed;
      if (particle.y < -18) {
        _resetParticle(particle, atBottom: true);
      }
    }

    if (_targetLift <= 0 &&
        _currentLift < GameConfig.thermalColumnMinimumLift * .25) {
      deactivate();
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!_active || !visible) return;

    final strength = (_currentLift / GameConfig.thermalLiftForce)
        .clamp(0.0, 1.0)
        .toDouble();
    final coreY = _coreY;
    final columnBounds = Rect.fromCenter(
      center: Offset(_centerX, GameConfig.designHeight * .5),
      width: _radius * 2.7,
      height: GameConfig.designHeight * 1.08,
    );

    // A tapered, warm-air sheet gives the rising particles a readable column
    // silhouette without obscuring obstacles behind it.
    final columnPath = Path()
      ..moveTo(_centerX - _radius * .30, GameConfig.designHeight + 26)
      ..quadraticBezierTo(
        _centerX - _radius * 1.10,
        coreY + 20,
        _centerX - _radius * .22,
        -30,
      )
      ..lineTo(_centerX + _radius * .22, -30)
      ..quadraticBezierTo(
        _centerX + _radius * 1.10,
        coreY + 20,
        _centerX + _radius * .30,
        GameConfig.designHeight + 26,
      )
      ..close();
    final columnPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color.fromRGBO(255, 167, 38, .05 * strength),
          Color.fromRGBO(255, 214, 102, .18 * strength),
          Color.fromRGBO(255, 244, 190, .03 * strength),
        ],
      ).createShader(columnBounds)
      ..style = PaintingStyle.fill;
    canvas.drawPath(columnPath, columnPaint);

    // Quiet heat-shimmer strokes replace the old spinning rings. They rise in
    // the same direction as the lift and never form a full-height oval.
    final wispPaint = Paint()
      ..color = Color.fromRGBO(255, 238, 170, .30 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = coreY + (i - 1.5) * 68;
      final sway = math.sin(_time * 2.7 + i * 1.6) * _radius * .18;
      final path = Path()
        ..moveTo(_centerX + sway - 7, y + 18)
        ..cubicTo(
          _centerX - 12 + sway,
          y + 8,
          _centerX + 13 - sway,
          y - 7,
          _centerX + sway + 4,
          y - 20,
        );
      canvas.drawPath(path, wispPaint);
    }

    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (final particle in _particles) {
      final x = _centerX +
          particle.xFactor * _radius +
          math.sin(particle.xWobble + particle.phase) * _radius * .16;
      final alpha = (.25 + strength * .62) *
          (0.62 + math.sin(_time * 4 + particle.phase) * .24);
      particlePaint.color = Color.fromRGBO(
        255,
        244,
        194,
        alpha.clamp(0.0, 0.9).toDouble(),
      );
      particlePaint.strokeWidth = .7 + particle.radius * .22;
      particlePaint.strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, particle.y + particle.radius * 4.2),
        Offset(x - math.sin(particle.xWobble) * 2, particle.y),
        particlePaint,
      );
    }

    super.render(canvas);
  }

  ThermalSurfUpdate _currentSurfUpdate() {
    final bonusActive = _bonusTimer > 0;
    return ThermalSurfUpdate(
      liftMultiplier: bonusActive
          ? GameConfig.thermalSurfLiftMultiplier
          : 1.0 + surfProgress * GameConfig.thermalSurfProgressLiftBonus,
      progress: surfProgress,
      completedOrbit: false,
      bonusActive: bonusActive,
    );
  }

  double get _coreY =>
      GameConfig.designHeight * GameConfig.thermalColumnCoreYFraction;

  double _shortestAngle(double delta) {
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta < -math.pi) {
      delta += math.pi * 2;
    }
    return delta;
  }

  void _seedParticles() {
    if (_particles.isEmpty) {
      for (var i = 0; i < GameConfig.thermalColumnParticleCount; i++) {
        _particles.add(_newParticle(initial: true));
      }
      return;
    }
    for (final particle in _particles) {
      _resetParticle(particle, atBottom: false);
    }
  }

  _ThermalParticle _newParticle({required bool initial}) => _ThermalParticle(
        xFactor: _rng.nextDouble() * 1.6 - .8,
        y: initial
            ? _rng.nextDouble() * (GameConfig.designHeight + 30)
            : GameConfig.designHeight + 18,
        speed: 38 + _rng.nextDouble() * 66,
        wobbleSpeed: 1.6 + _rng.nextDouble() * 2.5,
        phase: _rng.nextDouble() * math.pi * 2,
        radius: .9 + _rng.nextDouble() * 1.7,
      );

  void _resetParticle(_ThermalParticle particle, {required bool atBottom}) {
    particle.xFactor = _rng.nextDouble() * 1.6 - .8;
    particle.y = atBottom
        ? GameConfig.designHeight + 18 + _rng.nextDouble() * 44
        : _rng.nextDouble() * (GameConfig.designHeight + 30);
    particle.speed = 38 + _rng.nextDouble() * 66;
    particle.wobbleSpeed = 1.6 + _rng.nextDouble() * 2.5;
    particle.phase = _rng.nextDouble() * math.pi * 2;
    particle.radius = .9 + _rng.nextDouble() * 1.7;
    particle.xWobble = 0;
  }
}

class _ThermalParticle {
  _ThermalParticle({
    required this.xFactor,
    required this.y,
    required this.speed,
    required this.wobbleSpeed,
    required this.phase,
    required this.radius,
  });

  double xFactor;
  double y;
  double speed;
  double wobbleSpeed;
  double phase;
  double radius;
  double xWobble = 0;
}

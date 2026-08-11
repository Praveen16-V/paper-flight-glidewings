import '../../core/enums/game_enums.dart';

/// Immutable, typed signal emitted by the live Flame world.
///
/// These events are intentionally smaller than analytics records: they are
/// synchronous in-memory coordination points for systems that should not need
/// to know about each other's concrete implementation.
abstract class GameplayEvent {
  const GameplayEvent();
}

/// A confirmed near-miss after the obstacle and plane have separated.
class NearMissGameplayEvent extends GameplayEvent {
  const NearMissGameplayEvent(this.tier);

  final NearMissTier tier;
}

/// Why a non-terminal defensive resource had to intervene.
enum DefensiveSaveSource {
  decoyClone,
  craneBrushOff,
  shieldReflection,
  shieldCharge,
  zenBounce,
}

/// Sent after a defensive save, letting pacing/feedback systems respond without
/// coupling the crash-resolution branch to a particular implementation.
class DefensiveSaveGameplayEvent extends GameplayEvent {
  const DefensiveSaveGameplayEvent({
    required this.source,
    required this.severity,
  });

  final DefensiveSaveSource source;

  /// Normalized 0..1 relief strength for consumers such as dynamic difficulty.
  final double severity;
}

/// Sent when a paper-snap fully breaks an eligible obstacle.
class ObstacleDestroyedGameplayEvent extends GameplayEvent {
  const ObstacleDestroyedGameplayEvent(this.type);

  final ObstacleType type;
}

/// Handle returned by [GameplayEventBus.on]. Cancellation is idempotent and
/// safe to call while another listener is processing the same event.
class GameplayEventSubscription {
  GameplayEventSubscription(this._onCancel);

  final void Function() _onCancel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel();
  }
}

/// Lightweight typed event bus for one live game instance.
///
/// Dispatch snapshots the listener list, so a callback can subscribe or cancel
/// without corrupting the current iteration. It deliberately has no async
/// streams, allocations, or global singleton state in the gameplay hot path.
class GameplayEventBus {
  final Map<Type, List<void Function(GameplayEvent)>> _listeners = {};
  bool _disposed = false;

  GameplayEventSubscription on<T extends GameplayEvent>(
    void Function(T event) listener,
  ) {
    if (_disposed) return GameplayEventSubscription(() {});

    final Type type = T;
    void dispatch(GameplayEvent event) => listener(event as T);
    final listeners = _listeners.putIfAbsent(type, () => []);
    listeners.add(dispatch);
    return GameplayEventSubscription(() {
      listeners.remove(dispatch);
      if (listeners.isEmpty) _listeners.remove(type);
    });
  }

  void emit(GameplayEvent event) {
    if (_disposed) return;
    final listeners = _listeners[event.runtimeType];
    if (listeners == null || listeners.isEmpty) return;
    for (final listener in List<void Function(GameplayEvent)>.from(listeners)) {
      listener(event);
    }
  }

  int listenerCount<T extends GameplayEvent>() {
    final Type type = T;
    return _listeners[type]?.length ?? 0;
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

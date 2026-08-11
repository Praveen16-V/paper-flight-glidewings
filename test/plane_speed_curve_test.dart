import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  double classicSpeed(PlaneType plane, double meters) {
    return GameConfig.curvedScrollSpeedForDistance(
      meters: meters,
      baseSpeed: GameConfig.baseScrollSpeed,
      speedPerMeter: GameConfig.scrollSpeedPerMeter,
      maxSpeed: GameConfig.maxScrollSpeed,
      curveMultiplier: plane.speedCurveMultiplier,
      capMultiplier: plane.speedCapMultiplier,
    );
  }

  group('per-plane world-speed curves', () {
    test('Dart and Interceptor reach early speed ahead of the baseline curve',
        () {
      final baseline = GameConfig.curvedScrollSpeedForDistance(
        meters: 1000,
        baseSpeed: GameConfig.baseScrollSpeed,
        speedPerMeter: GameConfig.scrollSpeedPerMeter,
        maxSpeed: GameConfig.maxScrollSpeed,
        curveMultiplier: 1.0,
        capMultiplier: 1.0,
      );

      expect(classicSpeed(PlaneType.dart, 1000), greaterThan(baseline));
      expect(
        classicSpeed(PlaneType.interceptor, 1000),
        greaterThan(classicSpeed(PlaneType.dart, 1000)),
      );
    });

    test('Bomber and Glider trade a slower opening for higher long-haul caps',
        () {
      final baselineEarly = GameConfig.curvedScrollSpeedForDistance(
        meters: 1000,
        baseSpeed: GameConfig.baseScrollSpeed,
        speedPerMeter: GameConfig.scrollSpeedPerMeter,
        maxSpeed: GameConfig.maxScrollSpeed,
        curveMultiplier: 1.0,
        capMultiplier: 1.0,
      );

      expect(classicSpeed(PlaneType.bomber, 1000), lessThan(baselineEarly));
      expect(classicSpeed(PlaneType.glider, 1000), lessThan(baselineEarly));
      expect(
        classicSpeed(PlaneType.bomber, 6000),
        greaterThan(GameConfig.maxScrollSpeed),
      );
      expect(
        classicSpeed(PlaneType.glider, 6000),
        greaterThan(GameConfig.maxScrollSpeed),
      );
    });

    test('a curve never drops below launch speed or exceeds its own cap', () {
      final bomberCap =
          GameConfig.maxScrollSpeed * PlaneType.bomber.speedCapMultiplier;
      expect(classicSpeed(PlaneType.bomber, -100), GameConfig.baseScrollSpeed);
      expect(classicSpeed(PlaneType.bomber, 999999), closeTo(bomberCap, 0.001));
    });
  });
}

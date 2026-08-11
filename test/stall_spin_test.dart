import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('stall and spin tuning', () {
    test('effective angle of attack rises for a slow, steep climb', () {
      final shallow = GameConfig.angleOfAttackFor(
        forwardAirspeed: 180,
        verticalVelocity: -45,
        holdingLift: false,
      );
      final steep = GameConfig.angleOfAttackFor(
        forwardAirspeed: 105,
        verticalVelocity: -220,
        holdingLift: true,
      );

      expect(steep, greaterThan(shallow));
      expect(steep, greaterThan(GameConfig.stallAngleOfAttackThreshold));
    });

    test('descending or level flight has no climb-induced stall angle', () {
      final level = GameConfig.angleOfAttackFor(
        forwardAirspeed: 140,
        verticalVelocity: 0,
        holdingLift: false,
      );
      final descending = GameConfig.angleOfAttackFor(
        forwardAirspeed: 140,
        verticalVelocity: 80,
        holdingLift: false,
      );

      expect(level, 0.0);
      expect(descending, 0.0);
    });

    test('spin remains a recoverable flight-control state', () {
      expect(
        FlightControlState.values,
        containsAll(<FlightControlState>[
          FlightControlState.stable,
          FlightControlState.stallWarning,
          FlightControlState.spinning,
        ]),
      );
      expect(GameConfig.spinRecoveryDuration, greaterThan(0));
      expect(GameConfig.spinRecoveryInputThreshold, inInclusiveRange(0.0, 1.0));
    });
  });
}

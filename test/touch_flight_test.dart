import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/constants/game_config.dart';

void main() {
  group('touch flight stability', () {
    test('normal steering cannot rotate the plane into a flip', () {
      expect(
        GameConfig.planeMaxBankAngleRadians,
        lessThan(math.pi / 2),
      );
    });

    test('ambient wing flex remains a subtle deformation', () {
      expect(GameConfig.wingFlexMaxVisualBend, lessThan(0.5));
      expect(GameConfig.wingFlexOpenOvershoot, lessThan(0.2));
    });
  });
}

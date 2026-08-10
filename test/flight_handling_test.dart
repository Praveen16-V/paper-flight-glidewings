// Flight handling data tests — dynamic wing loading must remain intentional.

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  group('PlaneType wing loading', () {
    test('every airframe has a positive relative loading', () {
      for (final plane in PlaneType.values) {
        expect(plane.wingLoading, greaterThan(0), reason: plane.displayName);
      }
    });

    test('light folds respond ahead of the neutral Paper Dart', () {
      expect(PlaneType.butterfly.wingLoading,
          lessThan(PlaneType.dart.wingLoading));
      expect(PlaneType.albatross.wingLoading,
          lessThan(PlaneType.dart.wingLoading));
    });

    test('heavy Bomber and Rocket retain more turn momentum', () {
      expect(PlaneType.bomber.wingLoading,
          greaterThan(PlaneType.dart.wingLoading));
      expect(PlaneType.rocket.wingLoading,
          greaterThan(PlaneType.dart.wingLoading));
      expect(PlaneType.bomber.wingLoading,
          greaterThan(PlaneType.rocket.wingLoading));
    });
  });
}

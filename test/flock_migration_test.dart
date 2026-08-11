import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/enums/game_enums.dart';

void main() {
  test('flock migration is a named early-warning obstacle type', () {
    expect(ObstacleType.flockMigration.displayName, 'Flock Migration');
    expect(ObstacleType.flockMigration.assetName, 'flock_migration');
    expect(ObstacleType.flockMigration.isCursedMagnetAttractable, isFalse);
  });
}

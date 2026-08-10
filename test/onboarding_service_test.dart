import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:paper_flight/core/enums/game_enums.dart';
import 'package:paper_flight/services/onboarding_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('paper_flight_test_');
    Hive.init(tempDirectory.path);
    await Hive.openBox<dynamic>('settings');
    await OnboardingService.instance.resetGuidance();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('tutorial completion persists in the settings box', () async {
    expect(OnboardingService.instance.hasCompletedTutorial, isFalse);

    await OnboardingService.instance.completeTutorial();

    expect(OnboardingService.instance.hasCompletedTutorial, isTrue);
  });

  test('mode tips are tracked independently', () async {
    await OnboardingService.instance.markModeTipSeen(GameMode.daily);

    expect(OnboardingService.instance.hasSeenModeTip(GameMode.daily), isTrue);
    expect(OnboardingService.instance.hasSeenModeTip(GameMode.classic), isFalse);
    expect(OnboardingService.instance.hasSeenModeTip(GameMode.zen), isFalse);
    expect(OnboardingService.instance.hasSeenModeTip(GameMode.trial), isFalse);
  });
}

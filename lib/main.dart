import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'models/save_data.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/iap_service.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Lock to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Full-screen immersive mode
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Hive persistence
      await Hive.initFlutter();
      Hive.registerAdapter(SaveDataAdapter());
      await Hive.openBox<SaveData>('save_data');
      await Hive.openBox('settings');
      // Daily Seeded Flight leaderboard (Task 8) — local-first storage.
      await Hive.openBox('daily_leaderboard');

      // Firebase — uses stub options until flutterfire configure is run.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Crashlytics — forward Flutter framework errors
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // AdMob init + pre-load ad inventory
      await MobileAds.instance.initialize();
      AdService.instance.preload();

      // IAP init
      await IapService.instance.initialize();

      // Analytics session start
      await AnalyticsService.instance.logAppOpen();

      runApp(const ProviderScope(child: PaperFlightApp()));
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

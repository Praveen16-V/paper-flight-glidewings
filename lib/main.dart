import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SaveDataAdapter());
      }
      await Hive.openBox<SaveData>('save_data');
      await Hive.openBox('settings');

      // Firebase — stub options until flutterfire configure is run.
      // Fail soft so local/dev builds still launch.
      var firebaseReady = false;
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      } catch (e, st) {
        debugPrint('Firebase init skipped: $e');
        debugPrintStack(stackTrace: st);
      }

      // AdMob init + pre-load ad inventory (fail soft on desktop/web).
      try {
        await MobileAds.instance.initialize();
        AdService.instance.preload();
      } catch (e) {
        debugPrint('AdMob init skipped: $e');
      }

      // IAP init
      try {
        await IapService.instance.initialize();
      } catch (e) {
        debugPrint('IAP init skipped: $e');
      }

      // Analytics session start
      if (firebaseReady) {
        try {
          await AnalyticsService.instance.logAppOpen();
        } catch (_) {}
      }

      runApp(const ProviderScope(child: PaperFlightApp()));
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrintStack(stackTrace: stack);
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}
    },
  );
}

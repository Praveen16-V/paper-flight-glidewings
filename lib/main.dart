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

// Top-level flag so the zone error handler can check Firebase state.
bool _firebaseReady = false;

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

      try {
        // Hive persistence
        await Hive.initFlutter();
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(SaveDataAdapter());
        }
        await Hive.openBox<SaveData>('save_data');
        await Hive.openBox('settings');

        // Firebase — stub options until flutterfire configure is run.
        // Fail soft so local/dev builds still launch.
        try {
          // Hot restart can preserve the native default Firebase app.  Do not
          // initialise it a second time: that emits a duplicate-app exception
          // and obscures actual game-start failures in logcat.
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }
          _firebaseReady = Firebase.apps.isNotEmpty;
          if (_firebaseReady) {
            FlutterError.onError =
                FirebaseCrashlytics.instance.recordFlutterFatalError;
          }
        } catch (e, st) {
          debugPrint('Firebase init skipped: $e');
          debugPrintStack(stackTrace: st);
        }

        // AdMob + IAP — Android/iOS only, fail soft.
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)) {
          try {
            await MobileAds.instance.initialize();
            AdService.instance.preload();
          } catch (e) {
            debugPrint('AdMob init skipped: $e');
          }

          try {
            await IapService.instance.initialize();
          } catch (e) {
            debugPrint('IAP init skipped: $e');
          }
        }

        // Analytics session start
        if (_firebaseReady) {
          try {
            await AnalyticsService.instance.logAppOpen();
          } catch (_) {}
        }
      } catch (e, st) {
        // Catch-all: log and continue so runApp always executes.
        debugPrint('Init error (non-fatal): $e');
        debugPrintStack(stackTrace: st);
      }

      // runApp is always reached, even if some init steps failed.
      runApp(const ProviderScope(child: PaperFlightApp()));
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrintStack(stackTrace: stack);
      try {
        if (_firebaseReady) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
      } catch (_) {}
    },
  );
}


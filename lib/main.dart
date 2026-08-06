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
        // Hot restart preserves the native default Firebase app, so Dart's
        // Firebase.apps may be empty while native already has DEFAULT.
        // The canonical fix is try-init and swallow duplicate-app.
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('duplicate-app') ||
              msg.contains('already exists')) {
            // Expected on hot restart — treat as ready.
            debugPrint('Firebase already initialized (hot restart).');
          } else {
            debugPrint('Firebase init skipped: $e');
          }
        }
        _firebaseReady = Firebase.apps.isNotEmpty;
        if (_firebaseReady) {
          try {
            FlutterError.onError =
                FirebaseCrashlytics.instance.recordFlutterFatalError;
          } catch (_) {}
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


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/app_spacing.dart';
import 'core/constants/app_typography.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';
import 'screens/splash_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/hangar_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/daily_challenges_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/daily_flight_screen.dart';
import 'screens/trials_screen.dart';
import 'screens/trial_results_screen.dart';

class PaperFlightApp extends ConsumerStatefulWidget {
  const PaperFlightApp({super.key});

  @override
  ConsumerState<PaperFlightApp> createState() => _PaperFlightAppState();
}

/// Owns app-wide lifecycle telemetry.
///
/// A gameplay screen has a separate observer for auto-pause. Keeping session
/// measurement here means retention/session-length data also includes players
/// who browse the hangar, challenges, or shop without starting a run.
class _PaperFlightAppState extends ConsumerState<PaperFlightApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.startAppSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AnalyticsService.instance.startAppSession();
        break;
      case AppLifecycleState.inactive:
        // Transient interruptions (notification shade, system permission, ad
        // presentation) should not split one foreground session.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(
          AnalyticsService.instance.endAppSession(reason: state.name),
        );
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AnalyticsService.instance.endAppSession(reason: 'app_disposed'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.text('app.title'),
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentAlt,
        surface: AppColors.surface,
        background: AppColors.background,
        onPrimary: AppColors.textLight,
        onSurface: AppColors.textLight,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.body,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineMedium: AppTypography.headline,
        titleLarge: AppTypography.title,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.label,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.paperInk,
          minimumSize: const Size(200, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fade(const SplashScreen());
      case AppRoutes.mainMenu:
        return _fade(const MainMenuScreen());
      case AppRoutes.game:
        final args = settings.arguments as GameScreenArgs?;
        return _fade(GameScreen(args: args ?? const GameScreenArgs()));
      case AppRoutes.gameOver:
        final args = settings.arguments as GameOverArgs?;
        return _slide(GameOverScreen(args: args ?? const GameOverArgs()));
      case AppRoutes.hangar:
        return _slide(const HangarScreen());
      case AppRoutes.shop:
        return _slide(const ShopScreen());
      case AppRoutes.settings:
        return _slide(const SettingsScreen());
      case AppRoutes.dailyChallenges:
        return _slide(const DailyChallengesScreen());
      case AppRoutes.modes:
        return _slide(const ModesScreen());
      case AppRoutes.dailyFlight:
        return _slide(const DailyFlightScreen());
      case AppRoutes.trials:
        return _slide(const TrialsScreen());
      case AppRoutes.trialResult:
        final args = settings.arguments as TrialResultArgs?;
        return _slide(
            TrialResultsScreen(args: args ?? const TrialResultArgs()));
      default:
        return _fade(const SplashScreen());
    }
  }

  PageRouteBuilder<T> _fade<T>(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      );

  /// Slide-up transition used for sheets/results screens.
  ///
  /// Keep the route backdrop opaque and animate only the incoming page. A
  /// fading full-screen route exposes the still-rendering Flame canvas below
  /// during pushReplacement; when the game is also emitting crash effects that
  /// reads as a flicker before the results screen settles.
  PageRouteBuilder<T> _slide<T>(Widget page) => PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return ColoredBox(
            color: AppColors.background,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
      );
}

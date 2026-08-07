import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
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

class PaperFlightApp extends ConsumerWidget {
  const PaperFlightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Paper Flight',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
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
      fontFamily: 'Nunito', // fallback to system if not bundled
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textLight,
          minimumSize: const Size(200, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
        transitionDuration: const Duration(milliseconds: 300),
      );

  PageRouteBuilder<T> _slide<T>(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      );
}

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Central type system for Paper Flight.
///
/// * [Fredoka] — rounded geometric display face for headings, titles & scores.
///   Its soft terminals read as paper-cut / rounded display type.
/// * [Nunito] — clean geometric sans for body copy and subtext.
/// * [JetBrainsMono] — monospaced face for numeric counters (score, distance,
///   coins) so digits don't jitter horizontally as they tick up.
///
/// Variable-font weight axis is driven via [FontWeight]. All families are
/// bundled under `assets/fonts/` (see pubspec.yaml).
class AppTypography {
  AppTypography._();

  static const String display = 'Fredoka';
  static const String body = 'Nunito';
  static const String mono = 'JetBrainsMono';

  /// Force tabular figures so numeric counters never shift horizontally.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ── Display / headings (Fredoka) ─────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 46,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.05,
    color: AppColors.textLight,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: display,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textLight,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: display,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textLight,
  );

  static const TextStyle title = TextStyle(
    fontFamily: display,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AppColors.textLight,
  );

  // ── Body (Nunito) ────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: body,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.35,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.textMuted,
  );

  // ── Numeric counters (JetBrains Mono, tabular) ───────────────────────────
  static const TextStyle score = TextStyle(
    fontFamily: mono,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textLight,
    fontFeatures: _tabular,
  );

  static const TextStyle stat = TextStyle(
    fontFamily: mono,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textLight,
    fontFeatures: _tabular,
  );

  static const TextStyle statSmall = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textLight,
    fontFeatures: _tabular,
  );

  static const TextStyle label = TextStyle(
    fontFamily: display,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textLight,
  );

  // ── On-paper surfaces (cream / kraft sheets) ─────────────────────────────
  static const TextStyle titleOnPaper = TextStyle(
    fontFamily: display,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AppColors.paperInk,
  );

  static const TextStyle bodyOnPaper = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.paperInk,
    height: 1.45,
  );

  static const TextStyle captionOnPaper = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.paperInkSoft,
    height: 1.35,
  );
}

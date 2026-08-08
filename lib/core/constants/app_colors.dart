import 'package:flutter/material.dart';

/// Paper Flight — paper-craft / origami palette.
///
/// The app lives against a deep night-sky backdrop, while all cards, chips and
/// dialogs are *lighter sheets of folded paper* stacked above it. This gives
/// the distinctive origami-tabletop contrast instead of a generic dark-mode UI.
abstract class AppColors {
  // ── Sky / backgrounds ────────────────────────────────────────────────────
  static const Color skyDay = Color(0xFFB8D8E8);
  static const Color skyDusk = Color(0xFFE8C4A0);
  static const Color skyNight = Color(0xFF101833);
  static const Color skyStorm = Color(0xFF4A5568);

  // ── App chrome (deep night-sky layers) ───────────────────────────────────
  /// Deepest backdrop — the "table" the paper sits on.
  static const Color background = Color(0xFF131C38);
  static const Color backgroundDeep = Color(0xFF0C1228);
  static const Color surface = Color(0xFF1B2748);
  static const Color surfaceAlt = Color(0xFF243360);
  static const Color divider = Color(0xFF3A4D7A);

  // ── Paper sheets (cards / dialogs / panels) ──────────────────────────────
  // Cream / kraft paper sheets read as "coloured paper" against the dark sky.
  static const Color paper = Color(0xFFF6EEDC); // primary cream sheet
  static const Color paperBright = Color(0xFFFCF7EA); // top / highlighted sheet
  static const Color paperWarm = Color(0xFFEFE0C2); // lower / recessed sheet
  static const Color paperKraft = Color(0xFFE3CFA6); // brown kraft accent sheet
  static const Color paperInk = Color(0xFF2A3354); // ink on paper (text)
  static const Color paperInkSoft = Color(0xFF6B6450); // muted ink on paper

  // Tinted paper sheets for mode accents.
  static const Color paperBlue = Color(0xFFDCEBF4);
  static const Color paperGreen = Color(0xFFD9EDD6);
  static const Color paperGold = Color(0xFFF6E3AE);
  static const Color paperRose = Color(0xFFF6DAD2);

  // ── Brand accents ────────────────────────────────────────────────────────
  static const Color accent = Color(0xFFF5A623); // warm paper-fold gold
  static const Color accentDeep = Color(0xFFD98A12); // folded-under gold edge
  static const Color accentAlt = Color(0xFF4FC3F7); // sky blue highlight

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textLight = Color(0xFFF7F9FC);
  static const Color textMuted = Color(0xFF8A9BB8);

  // ── Collectibles ─────────────────────────────────────────────────────────
  static const Color coinGold = Color(0xFFFFC83D);
  static const Color coinGoldDeep = Color(0xFFE09A16);
  static const Color coinHighlight = Color(0xFFFFF1B0);
  static const Color gemBlue = Color(0xFF54C8EC);
  static const Color gemBlueDeep = Color(0xFF2A86B5);
  static const Color gemHighlight = Color(0xFFD6F4FF);

  // ── Status / feedback ────────────────────────────────────────────────────
  static const Color success = Color(0xFF56CF87);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFC947);

  // ── HUD ──────────────────────────────────────────────────────────────────
  static const Color hudBackground = Color(0xBB000000); // semi-transparent
  static const Color shieldBlue = Color(0xFF64B5F6);
  static const Color nearMissGlow = Color(0xFFFFEB3B);

  // ── Sky gradient ─────────────────────────────────────────────────────────
  /// Deeper, richer gradient used by splash + screen bodies.
  static const Color gradientTop = Color(0xFF1E2D56);
  static const Color gradientBottom = Color(0xFF0A0F1E);

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientTop, background, gradientBottom],
    stops: [0.0, 0.55, 1.0],
  );

  // ── Biome-tint overlays ──────────────────────────────────────────────────
  static const Color biomeCityTint = Color(0x1A4A90D9);
  static const Color biomeStormTint = Color(0x1A37474F);
  static const Color biomeMountainTint = Color(0x1A4CAF50);
  static const Color biomeNightTint = Color(0x331A1F3A);
  static const Color biomeAtmosTint = Color(0x1A7B1FA2);
}

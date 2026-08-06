import 'package:flutter/material.dart';

/// Paper Flight flat paper-craft palette.
/// Soft, warm sky tones — avoids harsh neon for the paper aesthetic.
abstract class AppColors {
  // Sky / backgrounds
  static const Color skyDay = Color(0xFFB8D8E8);
  static const Color skyDusk = Color(0xFFE8C4A0);
  static const Color skyNight = Color(0xFF1A1F3A);
  static const Color skyStorm = Color(0xFF4A5568);

  // App chrome
  static const Color background = Color(0xFF1A2744);
  static const Color surface = Color(0xFF243050);
  static const Color surfaceAlt = Color(0xFF2E3D66);
  static const Color divider = Color(0xFF3A4D7A);

  // Brand accent — warm paper-fold gold
  static const Color accent = Color(0xFFF5A623);
  static const Color accentAlt = Color(0xFF4FC3F7); // sky blue highlight

  // Text
  static const Color textLight = Color(0xFFF7F9FC);
  static const Color textMuted = Color(0xFF8A9BB8);

  // Collectibles
  static const Color coinGold = Color(0xFFFFD700);
  static const Color gemBlue = Color(0xFF48CAE4);

  // Status / feedback
  static const Color success = Color(0xFF56CF87);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFC947);

  // HUD
  static const Color hudBackground = Color(0xBB000000); // semi-transparent
  static const Color shieldBlue = Color(0xFF64B5F6);
  static const Color nearMissGlow = Color(0xFFFFEB3B);

  // Biome-tint overlays (subtle screen tints per biome)
  static const Color biomeCityTint = Color(0x1A4A90D9);
  static const Color biomeStormTint = Color(0x1A37474F);
  static const Color biomeMountainTint = Color(0x1A4CAF50);
  static const Color biomeNightTint = Color(0x331A1F3A);
  static const Color biomeAtmosTint = Color(0x1A7B1FA2);
}

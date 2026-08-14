/// Shared spacing and corner-radius tokens for the paper-craft design system.
abstract class AppRadius {
  AppRadius._();

  /// Small chips, icon buttons, segmented controls.
  static const double sm = 12;

  /// Buttons (PaperButton, ElevatedButton).
  static const double button = 14;

  /// Cards, panels, mode preview sheets.
  static const double md = 16;

  /// Primary PaperCard default radius.
  static const double lg = 20;

  /// Pill badges and currency wrappers.
  static const double pill = 22;
}

abstract class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;

  /// Default inner padding for [PaperCard].
  static const double cardPadding = 18;
}

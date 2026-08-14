import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Static night-sky gradient backdrop for secondary menu-flow screens.
///
/// Animated [SkyBackdrop] is reserved for splash + main menu; this widget
/// applies the same [AppColors.skyGradient] without animation cost.
class ScreenBackdrop extends StatelessWidget {
  const ScreenBackdrop({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.skyGradient,
      ),
      child: child,
    );
  }
}

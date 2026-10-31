import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Single source for depth: shadows. Light mode uses shadows; dark mode drops them, since they vanish on black.
abstract class AppEffects {
  /// Standard card lift: a tight contact shadow plus a wide ambient one.
  static List<BoxShadow> card(AppPalette p) {
    if (p.isDark) return const [];
    return [
      BoxShadow(
        color: p.ink.withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: p.ink.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// Hero-level lift for the one card that overlaps a hero and must read as above it.
  static List<BoxShadow> raised(AppPalette p) {
    if (p.isDark) return const [];
    return [
      BoxShadow(
        color: p.ink.withValues(alpha: 0.06),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: p.ink.withValues(alpha: 0.14),
        blurRadius: 40,
        offset: const Offset(0, 18),
      ),
    ];
  }

  /// Hairline used on panels in dark mode, where shadows do not show.
  static Border hairline(AppPalette p) =>
      Border.all(color: p.isDark ? p.glassBorder : Colors.transparent);

  /// Blur strength for glass surfaces. Lower this on slow devices.
  static double glassBlur(AppPalette p) => p.isDark ? 28 : 22;

  /// Dark pill button lift.
  static List<BoxShadow> cta(AppPalette p) {
    if (p.isDark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ];
  }
}

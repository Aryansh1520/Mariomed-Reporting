import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_colors.dart';
import 'app_system_ui.dart';
import 'app_tokens.dart';

/// One neutral UI sans (Inter) for every text style, the same as the reference app.
abstract class AppTheme {
  static TextTheme _textTheme(AppPalette p) {
    final base = ThemeData(brightness: p.brightness).textTheme;

    TextStyle display(TextStyle? s) =>
        GoogleFonts.inter(textStyle: s, color: p.ink);
    TextStyle body(TextStyle? s) =>
        GoogleFonts.inter(textStyle: s, color: p.ink);

    return base.copyWith(
      displayLarge: display(base.displayLarge),
      displayMedium: display(base.displayMedium),
      displaySmall: display(base.displaySmall),
      headlineLarge: display(base.headlineLarge),
      headlineMedium: display(base.headlineMedium),
      headlineSmall: display(base.headlineSmall),
      titleLarge: display(base.titleLarge),
      titleMedium: body(base.titleMedium),
      titleSmall: body(base.titleSmall),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    );
  }

  static ThemeData material(AppPalette p) {
    final text = _textTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: p.accent,
        onSecondary: p.onAccent,
        error: p.alert,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.ink,
      ),
      // The gradient is drawn once at the app root, so screens stay transparent.
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: AppSystemUi.styleFor(lightIcons: p.isDark),
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Page titles are the main heading of each screen, so they are set well above body text.
        toolbarHeight: 64,
        titleTextStyle: text.headlineMedium?.copyWith(
          fontSize: 32,
          height: 1.1,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.primary
                : p.inkMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.m,
          ),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: AppSpace.m,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
    );
  }

  /// shadcn_ui components read their colours from here, so they match the app.
  static ShadThemeData shad(AppPalette p) {
    return ShadThemeData(
      brightness: p.brightness,
      colorScheme: ShadColorScheme(
        background: p.background,
        foreground: p.ink,
        card: p.surface,
        cardForeground: p.ink,
        popover: p.surface,
        popoverForeground: p.ink,
        primary: p.primary,
        primaryForeground: p.onPrimary,
        secondary: p.surfaceRaised,
        secondaryForeground: p.ink,
        muted: p.surfaceRaised,
        mutedForeground: p.inkMuted,
        accent: p.accent,
        accentForeground: p.onAccent,
        destructive: p.alert,
        destructiveForeground: Colors.white,
        border: p.border,
        input: p.border,
        ring: p.primary,
        selection: p.primary.withValues(alpha: 0.3),
      ),
    );
  }

  static final light = material(AppPalette.light);
  static final dark = material(AppPalette.dark);
}

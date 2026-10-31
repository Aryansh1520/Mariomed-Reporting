import 'package:flutter/material.dart';

/// THE COLOUR FILE. Change colours here and nowhere else.
/// Widgets read colours through `context.palette`; no `Colors.*` literals in screens.
///
/// Semantic meaning (keep the meaning when recolouring):
///   go       green : done, on target, approved
///   alert    red   : stop, overdue, rejected
///   warning  amber : caution, due today, needs attention
///   info     blue  : new, scheduled, neutral information
///   primary  cobalt: app identity, selection, active states
///   accent   sky   : highlights and secondary emphasis
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.go,
    required this.alert,
    required this.warning,
    required this.info,
    required this.cta,
    required this.onCta,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.heroStops,
    required this.heroCool,
    required this.onHero,
    required this.glassTint,
    required this.glassBorder,
    required this.glassTray,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color go;
  final Color alert;
  final Color warning;
  final Color info;

  /// Primary pill buttons.
  final Color cta;
  final Color onCta;

  /// Canvas gradient, top to bottom.
  final Color backgroundTop;
  final Color backgroundBottom;

  /// The mesh hero: a diagonal ramp from deep navy to pale ice, plus a grey-blue haze for the blurred blobs.
  final List<Color> heroStops;
  final Color heroCool;

  /// Text and icons placed on the hero.
  final Color onHero;

  /// Frosted glass: the translucent fill, its hairline edge, and the fill of the tray inside the hero.
  final Color glassTint;
  final Color glassBorder;
  final Color glassTray;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F7FC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEAF0F9),
    ink: Color(0xFF0D1B2E),
    inkMuted: Color(0xFF5A6A82),
    border: Color(0xFFD9E2F0),
    primary: Color(0xFF1456D8),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF3FA9F5),
    onAccent: Color(0xFF062240),
    go: Color(0xFF1E9E68),
    alert: Color(0xFFD63B33),
    warning: Color(0xFFD99A00),
    info: Color(0xFF2E7DF6),
    cta: Color(0xFF0F2F6E),
    onCta: Color(0xFFFFFFFF),
    backgroundTop: Color(0xFFF6F9FE),
    backgroundBottom: Color(0xFFEDF3FB),
    heroStops: [
      Color(0xFF0B1F4D),
      Color(0xFF1A3F8F),
      Color(0xFF2A63D6),
      Color(0xFF4C8BF5),
      Color(0xFF1A3F8F),
      Color(0xFF2A63D6),
      Color(0xFF4C8BF5),
      Color(0xFF0B1F4D),
    ],
    heroCool: Color(0xFF2A4A86),
    onHero: Color(0xFFFFFFFF),
    glassTint: Color(0x99FFFFFF),
    glassBorder: Color(0x66FFFFFF),
    glassTray: Color(0x99FFFFFF),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF05080F),
    surface: Color(0xFF0C1322),
    surfaceRaised: Color(0xFF141E33),
    ink: Color(0xFFE9EFFA),
    inkMuted: Color(0xFF8493AD),
    border: Color(0xFF1C2842),
    primary: Color(0xFF5B8DFF),
    onPrimary: Color(0xFF05080F),
    accent: Color(0xFF6CC4FF),
    onAccent: Color(0xFF05080F),
    go: Color(0xFF34C27F),
    alert: Color(0xFFFF6B61),
    warning: Color(0xFFFFC93C),
    info: Color(0xFF5B8DFF),
    cta: Color(0xFFE9EFFA),
    onCta: Color(0xFF05080F),
    backgroundTop: Color(0xFF05080F),
    backgroundBottom: Color(0xFF05080F),
    heroStops: [
      Color(0xFF0B2A6B),
      Color(0xFF1A4BB0),
      Color(0xFF2A63D6),
      Color(0xFF4C8BF5),
      Color(0xFF1A4BB0),
      Color(0xFF2A63D6),
      Color(0xFF4C8BF5),
      Color(0xFF0B2A6B),
    ],
    heroCool: Color(0xFF1F3F80),
    onHero: Color(0xFFFFFFFF),
    glassTint: Color(0x1FFFFFFF),
    glassBorder: Color(0x24FFFFFF),
    glassTray: Color(0x800C1322),
  );
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}

/// One colour per zone, in the order zones are drawn. Subzones take their zone's colour.
/// Each colour reads on both the light and the dark canvas.
const territoryHues = <Color>[
  Color(0xFF4C8BF5),
  Color(0xFF1E9E68),
  Color(0xFFE8833A),
  Color(0xFFB35CE0),
  Color(0xFFE0525A),
  Color(0xFF1BA8B5),
  Color(0xFFD9A71E),
  Color(0xFFE05BA6),
];

Color territoryHue(int index) => territoryHues[index % territoryHues.length];

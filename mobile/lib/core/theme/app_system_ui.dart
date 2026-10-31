import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Lets the system bars sit on the app canvas, so the bottom bar blends into the gradient.
abstract class AppSystemUi {
  static void enableEdgeToEdge() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static void apply(AppPalette p) {
    SystemChrome.setSystemUIOverlayStyle(styleFor(lightIcons: p.isDark));
  }

  /// Status bar icons are light in dark mode and dark in light mode. The navigation bar stays on the canvas.
  static SystemUiOverlayStyle styleFor({required bool lightIcons}) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android reads the icon brightness; iOS reads the status bar background brightness instead.
      statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
      statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: lightIcons
          ? Brightness.light
          : Brightness.dark,
    );
  }
}

import 'package:flutter/material.dart';

/// Shape, spacing and motion tokens. Change them here, not in widgets.
abstract class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(10));
  static const md = BorderRadius.all(Radius.circular(16));
  static const lg = BorderRadius.all(Radius.circular(24));
  static const xl = BorderRadius.all(Radius.circular(32));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  /// Screens slide across the whole duration; easeOut would finish most of the move almost at once.
  static const pageCurve = Curves.easeInOutCubic;
}

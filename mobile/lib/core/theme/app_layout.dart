import 'package:flutter/widgets.dart';

/// Three layouts, one per screen size. Phones get one column. Tablets get one centred column.
/// Desktops get a wider column and two-column screens where the content reads better side by side.
enum ScreenSize { compact, medium, expanded }

abstract class AppLayout {
  static const mediumFrom = 600.0;
  static const expandedFrom = 1024.0;

  static const compactMaxWidth = double.infinity;
  static const mediumMaxWidth = 760.0;
  static const expandedMaxWidth = 1200.0;

  /// Auth and single-purpose forms read best as a narrow column at every size.
  static const formMaxWidth = 440.0;

  /// Centred dialogs stay narrow so their text keeps a readable line length.
  static const dialogMaxWidth = 400.0;

  static ScreenSize sizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expandedFrom) return ScreenSize.expanded;
    if (width >= mediumFrom) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  static double contentMaxWidth(ScreenSize size) => switch (size) {
    ScreenSize.compact => compactMaxWidth,
    ScreenSize.medium => mediumMaxWidth,
    ScreenSize.expanded => expandedMaxWidth,
  };

  /// Phones narrower than this get a tighter gutter, so content keeps its room.
  static const narrowBelow = 380.0;
  static const narrowGutter = 12.0;

  /// The side gutter for the screen the context is in. Narrow phones get [narrowGutter].
  static double gutterOf(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < narrowBelow) return narrowGutter;
    return gutter(sizeOf(context));
  }

  static double gutter(ScreenSize size) => switch (size) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
  };
}

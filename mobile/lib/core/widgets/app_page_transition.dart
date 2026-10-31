import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_tokens.dart';
import 'app_backdrop.dart';

/// Slides a new screen in from the right over an opaque backdrop. The curve is ease-in-out, so
/// the motion runs through the whole duration instead of finishing in the first few frames.
class AppPageTransition extends CustomTransition {
  AppPageTransition();

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: AppMotion.pageCurve));

    return SlideTransition(
      position: slide,
      child: AppBackdrop(child: child),
    );
  }
}

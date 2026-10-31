import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app gradient under one screen. Screens are transparent, so a screen that is sliding in or
/// out needs its own gradient, or the screen beneath would show through.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.backgroundBottom],
        ),
      ),
      child: child,
    );
  }
}

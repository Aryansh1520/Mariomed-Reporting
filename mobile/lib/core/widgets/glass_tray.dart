import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// Frosted outer ring around an inner card. The inner card uses the same translucent fill and
/// blur as the bottom bar, so the two read at one opacity in both modes.
class GlassTray extends StatelessWidget {
  const GlassTray({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassSurface(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpace.s),
      child: DecoratedBox(
        // The shadow sits outside the blur clip, so it still lifts the card.
        decoration: BoxDecoration(
          borderRadius: AppRadius.lg,
          boxShadow: AppEffects.card(p),
        ),
        child: GlassSurface(
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(AppSpace.xl),
          tint: p.glassTray,
          child: child,
        ),
      ),
    );
  }
}

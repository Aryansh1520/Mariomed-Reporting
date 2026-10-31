import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_tokens.dart';
import 'press_scale.dart';

/// The app's card: a surface with the standard lift, and an optional art layer painted behind the
/// content so text always sits on top.
class WhiteCard extends StatelessWidget {
  const WhiteCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.art,
    this.artAlignment = Alignment.topRight,
    this.artBottomInset = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Widget? art;
  final Alignment artAlignment;

  /// Keeps the art above a bottom element, such as the action pill.
  final double artBottomInset;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: Stack(
          children: [
            if (art != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: artBottomInset,
                child: IgnorePointer(
                  child: Align(alignment: artAlignment, child: art),
                ),
              ),
            Padding(
              padding: padding,
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ],
        ),
      ),
    );

    final tap = onTap;
    if (tap == null) return card;
    return PressScale(onTap: tap, child: card);
  }
}

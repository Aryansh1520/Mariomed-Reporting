import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_tokens.dart';
import 'press_scale.dart';

/// Dark pill button with an optional trailing icon.
class CtaButton extends StatelessWidget {
  const CtaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;

  /// Null draws the button disabled: it keeps its place and ignores taps.
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    final body = Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: AppSpace.m,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.pill,
          color: p.cta,
          boxShadow: AppEffects.cta(p),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: text.labelLarge?.copyWith(
                color: p.onCta,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: AppSpace.s),
              Icon(icon, color: p.onCta, size: 16),
            ],
          ],
        ),
      ),
    );
    return PressScale(onTap: onTap, child: body);
  }
}

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_tokens.dart';
import 'press_scale.dart';

/// Solid pill that sits on the hero's lower edge: count badge, message, chevron. Solid so its text stays readable on the hero.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.count,
    required this.message,
    this.onTap,
  });

  final int count;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    final bar = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, AppSpace.l, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.pill,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: Text(
              '$count',
              style: text.labelLarge?.copyWith(
                color: p.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
        ],
      ),
    );
    return PressScale(onTap: onTap, child: bar);
  }
}

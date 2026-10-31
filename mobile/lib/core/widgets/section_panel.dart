import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_tokens.dart';

/// A section in its own surface panel, with its title inside the panel.
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lg,
          boxShadow: AppEffects.card(p),
          border: AppEffects.hairline(p),
        ),
        // Clips scrolling content to the panel edge, so rows never run past the container.
        child: ClipRRect(
          borderRadius: AppRadius.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.l,
                  AppSpace.l,
                  AppSpace.l,
                  AppSpace.m,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ?action,
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

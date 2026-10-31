import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A figure with a tinted icon square: the value in bold, its label beneath. Used on the management lists.
class FigureChip extends StatelessWidget {
  const FigureChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AppSpace.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
          ],
        ),
      ],
    );
  }
}

/// The figures row under a management list item: calls, contacts and reps for products, or calls and contacts for categories.
class FigureRow extends StatelessWidget {
  const FigureRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.m,
      runSpacing: AppSpace.s,
      children: children,
    );
  }
}

/// The tinted blue, purple and green used for calls, contacts and reps across the dashboard.
const figureCallsColor = Color(0xFF1F5FDB);
const figureContactsColor = Color(0xFF7B5CE0);
const figureRepsColor = Color(0xFF1E9E5A);

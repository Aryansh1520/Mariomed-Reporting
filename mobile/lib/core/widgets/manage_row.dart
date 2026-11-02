import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Active or Inactive, as a small pill.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = active ? p.go : p.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: text.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Edit, and Delete (or Restore for an inactive item), at the bottom of a managed row. [onTypes] adds a Types action.
class ManageActions extends StatelessWidget {
  const ManageActions({
    super.key,
    required this.active,
    required this.onEdit,
    required this.onToggle,
    this.onTypes,
  });

  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback? onTypes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onTypes != null)
          TextButton.icon(
            onPressed: onTypes,
            icon: const Icon(Iconsax.category, size: 16),
            label: const Text('Types'),
          ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Iconsax.edit_2, size: 16),
          label: const Text('Edit'),
        ),
        TextButton.icon(
          onPressed: onToggle,
          icon: Icon(active ? Iconsax.trash : Iconsax.refresh, size: 16),
          label: Text(active ? 'Delete' : 'Restore'),
          style: active ? TextButton.styleFrom(foregroundColor: p.alert) : null,
        ),
      ],
    );
  }
}

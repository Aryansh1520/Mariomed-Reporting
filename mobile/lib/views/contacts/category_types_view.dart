import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/categories_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/manage_row.dart';
import '../../models/contact.dart';
import '../../services/auth_service.dart';

/// The types under one category, such as ortho or physician under doctors. Types are optional on contacts.
class CategoryTypesView extends GetView<CategoriesController> {
  const CategoryTypesView({super.key, required this.category});

  final ContactCategory category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final size = AppLayout.sizeOf(context);
    final canManage = Get.find<AuthService>().can('settings.manage');
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '${category.name} types',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'New type',
              icon: const Icon(Iconsax.add),
              onPressed: () => _rename(null),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: Obx(() => _body(canManage, AppLayout.gutter(size))),
        ),
      ),
    );
  }

  Widget _body(bool canManage, double gutter) {
    final types = controller.typesOf(category.id);
    if (types.isEmpty) {
      return const EmptyState(
        icon: Iconsax.category,
        title: 'No types yet',
        message: 'Types are optional. Add one, such as ortho or physician.',
      );
    }
    return ListView(
      padding: EdgeInsets.all(gutter),
      children: [
        _TypesCard(
          children: [
            for (final type in types)
              _TypeRow(
                type: type,
                canManage: canManage,
                onEdit: () => _rename(type),
                onToggle: () => _toggleActive(type),
              ),
          ],
        ),
      ],
    );
  }

  /// Adds a type under this category, or renames [contactType] when it is given.
  Future<void> _rename(ContactType? contactType) async {
    final name = await AppDialogs.prompt(
      title: contactType == null ? 'New type' : 'Rename type',
      label: 'Name',
      initial: contactType?.name ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    final problem = await controller.saveType(
      category.id,
      name.trim(),
      contactType: contactType,
    );
    if (problem != null) {
      await AppDialogs.error('Could not save the type', problem);
    }
  }

  /// Switches a type off after confirmation, or back on. Contacts that have it keep it.
  Future<void> _toggleActive(ContactType contactType) async {
    if (contactType.isActive) {
      final confirmed = await AppDialogs.confirm(
        title: 'Delete ${contactType.name}?',
        message: 'The type is switched off. Contacts keep it, but it cannot be given to new contacts.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed) return;
    }
    final problem = await controller.setTypeActive(
      contactType,
      isActive: !contactType.isActive,
    );
    if (problem != null) {
      await AppDialogs.error('Could not update the type', problem);
    }
  }
}

/// The types card, styled like the categories card.
class _TypesCard extends StatelessWidget {
  const _TypesCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.m),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One type: its name and status, then the actions when the caller may manage types.
class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final ContactType type;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type.name,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              StatusPill(active: type.isActive),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: AppSpace.s),
            ManageActions(
              active: type.isActive,
              onEdit: onEdit,
              onToggle: onToggle,
            ),
          ],
        ],
      ),
    );
  }
}

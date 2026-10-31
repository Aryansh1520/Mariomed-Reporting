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
import '../../core/widgets/loading_list.dart';
import '../../core/widgets/figure_chip.dart';
import '../../core/widgets/manage_row.dart';
import '../../models/contact.dart';
import '../admin/team_day_view.dart';
import '../../models/team_dashboard.dart';
import '../../services/auth_service.dart';

/// Contact categories: doctors, chemists, stockists and the rest. Managers can add, rename and switch them off.
class CategoriesView extends GetView<CategoriesController> {
  const CategoriesView({super.key});

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
          'Categories',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'New category',
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
    if (controller.isLoading.value) return const LoadingList(count: 4);
    final error = controller.errorMessage.value;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Could not load categories',
        message: error,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.all(gutter),
        children: [
          _CategoriesCard(
            count: controller.categories.length,
            showsStats: controller.showsStats,
            children: [
              for (final category in controller.categories)
                _CategoryRow(
                  category: category,
                  onOpen: () => Get.to(
                    () => CategoryStatsView(
                      categoryName: category.name,
                      stat: controller.stats[category.name],
                    ),
                  ),
                  stat: controller.stats[category.name],
                  showsStats: controller.showsStats,
                  canManage: canManage,
                  onEdit: () => _rename(category),
                  onToggle: () => _toggleActive(category),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Adds a category, or renames [category] when it is given.
  Future<void> _rename(ContactCategory? category) async {
    final name = await AppDialogs.prompt(
      title: category == null ? 'New category' : 'Rename category',
      label: 'Name',
      initial: category?.name ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    final problem = await controller.save(name.trim(), category: category);
    if (problem != null) {
      await AppDialogs.error('Could not save the category', problem);
    }
  }

  /// Switches a category off after confirmation, or back on. Contacts in a category that is off keep it.
  Future<void> _toggleActive(ContactCategory category) async {
    if (category.isActive) {
      final confirmed = await AppDialogs.confirm(
        title: 'Delete ${category.name}?',
        message: 'The category is switched off. Contacts keep it, but it cannot be given to new contacts.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed) return;
    }
    final problem = await controller.setActive(
      category,
      isActive: !category.isActive,
    );
    if (problem != null) {
      await AppDialogs.error('Could not update the category', problem);
    }
  }
}

/// The categories card: a tinted icon, the title, the count, then every category.
class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({
    required this.count,
    required this.showsStats,
    required this.children,
  });

  final int count;
  final bool showsStats;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.category, size: 20, color: p.primary),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(
                  'Categories',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              Text(
                '$count categories',
                style: text.bodyMedium?.copyWith(color: p.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.m),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One category, laid out like the product rows: a thumbnail, the name and status, the figures, then the actions.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onOpen,
    required this.stat,
    required this.showsStats,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final ContactCategory category;
  final VoidCallback onOpen;
  final CategoryLine? stat;
  final bool showsStats;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final active = category.isActive;
    final figures = stat;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: p.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? p.primary.withValues(alpha: 0.1)
                      : p.border.withValues(alpha: 0.5),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  Iconsax.category,
                  size: 30,
                  color: active ? p.primary : p.inkMuted,
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                        ),
                        StatusPill(active: active),
                      ],
                    ),
                    if (showsStats) ...[
                      const SizedBox(height: AppSpace.s),
                      FigureRow(
                        children: [
                          FigureChip(
                            icon: Iconsax.call,
                            value: '${figures?.calls ?? 0}',
                            label: 'Calls',
                            color: figureCallsColor,
                          ),
                          FigureChip(
                            icon: Iconsax.people,
                            value: '${figures?.contactsVisited ?? 0}',
                            label: 'Contacts',
                            color: figureContactsColor,
                          ),
                        ],
                      ),
                    ],
                    if (canManage) ...[
                      const SizedBox(height: AppSpace.s),
                      ManageActions(
                        active: active,
                        onEdit: onEdit,
                        onToggle: onToggle,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/products_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/figure_chip.dart';
import '../../core/widgets/manage_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/product.dart';
import '../admin/team_day_view.dart';
import '../../models/team_dashboard.dart';
import '../../services/auth_service.dart';

class ProductsView extends GetView<ProductsController> {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    final canManage = Get.find<AuthService>().can('products.manage');
    final size = AppLayout.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'New product',
              icon: const Icon(Iconsax.add),
              onPressed: () => _openForm(),
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
    if (controller.isLoading) return const LoadingList(count: 4);
    final error = controller.errorMessage;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Could not load products',
        message: error,
      );
    }
    if (controller.products.isEmpty) {
      return const EmptyState(
        icon: Iconsax.box,
        title: 'No products yet',
        message: 'Products you add appear here for the whole team.',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.loadProducts,
      child: ListView(
        padding: EdgeInsets.all(gutter),
        children: [
          _ProductsCard(
            count: controller.products.length,
            showsStats: controller.showsStats,
            children: [
              for (final product in controller.products)
                _ProductRow(
                  product: product,
                  onOpen: () => Get.to(
                    () => ProductStatsView(
                      productId: product.id,
                      name: product.name,
                      stat: controller.stats[product.id],
                    ),
                  ),
                  stat: controller.stats[product.id],
                  showsStats: controller.showsStats,
                  canManage: canManage,
                  onEdit: () => _openForm(product),
                  onToggle: () => _toggleActive(product),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Switches a product off after confirmation, or back on. A product that is off keeps its history.
  Future<void> _toggleActive(Product product) async {
    if (product.isActive) {
      final confirmed = await AppDialogs.confirm(
        title: 'Delete ${product.name}?',
        message: 'The product is switched off. Past calls keep it, but it cannot be used for new ones.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed) return;
    }
    final problem = await controller.setActive(
      product,
      isActive: !product.isActive,
    );
    if (problem != null) {
      await AppDialogs.error('Could not update the product', problem);
    }
  }

  /// Opens the form, then reloads the list when something was saved.
  Future<void> _openForm([Product? product]) async {
    final saved = product == null
        ? await Get.toNamed(AppRoutes.productNew)
        : await Get.toNamed(AppRoutes.productEdit, arguments: product);
    if (saved == true) await controller.loadProducts();
  }
}

/// The products card: a tinted icon, the title, the count, then every product.
class _ProductsCard extends StatelessWidget {
  const _ProductsCard({
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
                child: Icon(Iconsax.box, size: 20, color: p.primary),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Products',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                    if (showsStats)
                      Text(
                        'This month',
                        style: text.bodySmall?.copyWith(color: p.inkMuted),
                      ),
                  ],
                ),
              ),
              Text(
                '$count products',
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

/// One product, laid out like the dashboard's product rows: a thumbnail, the name and status, the figures, then the actions.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onOpen,
    required this.stat,
    required this.showsStats,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final Product product;
  final VoidCallback onOpen;
  final ProductLine? stat;
  final bool showsStats;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final active = product.isActive;
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
                  Iconsax.box,
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
                            product.name,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                        ),
                        StatusPill(active: active),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      product.code,
                      style: text.bodySmall?.copyWith(color: p.inkMuted),
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
                          FigureChip(
                            icon: Iconsax.user,
                            value: '${figures?.reps ?? 0}',
                            label: 'Reps',
                            color: figureRepsColor,
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

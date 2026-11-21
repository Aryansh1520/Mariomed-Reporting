import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/unlisted_patch_controller.dart';
import '../../controllers/unlisted_patches_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/business_time.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/figure_chip.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/unlisted.dart';

/// Unlisted doctors and chemists per patch: how many are still open, how many were converted, and the calls on them.
class UnlistedPatchesView extends GetView<UnlistedPatchesController> {
  const UnlistedPatchesView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          'Unlisted in patches',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Change period',
            onPressed: () => _pickPeriod(context),
            icon: const Icon(Iconsax.calendar_1),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: Obx(() => _body(context, AppLayout.gutterOf(context))),
        ),
      ),
    );
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final today = DateUtils.dateOnly(indiaToday());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: controller.from.value,
        end: controller.to.value,
      ),
    );
    if (picked != null) await controller.setPeriod(picked.start, picked.end);
  }

  Widget _body(BuildContext context, double gutter) {
    if (controller.isLoading) return const LoadingList(count: 3);
    final error = controller.errorMessage;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Could not load unlisted contacts',
        message: error,
      );
    }
    final patches = controller.patches;
    if (patches.isEmpty) {
      return const EmptyState(
        icon: Iconsax.user_add,
        title: 'No unlisted contacts',
        message: 'Doctors and chemists met off the list show here, by patch.',
      );
    }
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.all(gutter),
        children: [
          Text(
            '${formatDay(controller.from.value)}  to  ${formatDay(controller.to.value)}',
            style: text.bodySmall?.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: AppSpace.m),
          for (final patch in patches) ...[
            _PatchCard(patch: patch, onTap: () => _open(patch)),
            const SizedBox(height: AppSpace.m),
          ],
        ],
      ),
    );
  }

  void _open(UnlistedPatch patch) {
    Get.toNamed(
      AppRoutes.unlistedPatch,
      arguments: UnlistedPatchArgs(
        patch: patch,
        from: controller.from.value,
        to: controller.to.value,
      ),
    );
  }
}

/// One patch: its zone, the open and converted counts, the calls and reps, and the calls per kind of contact.
class _PatchCard extends StatelessWidget {
  const _PatchCard({required this.patch, required this.onTap});

  final UnlistedPatch patch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patch.subzoneName,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            patch.zoneName,
                            style: text.bodySmall?.copyWith(color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
                  ],
                ),
                const SizedBox(height: AppSpace.m),
                Wrap(
                  spacing: AppSpace.l,
                  runSpacing: AppSpace.s,
                  children: [
                    FigureChip(
                      icon: Iconsax.user_add,
                      value: '${patch.unlisted}',
                      label: 'Open',
                      color: p.warning,
                    ),
                    FigureChip(
                      icon: Iconsax.tick_circle,
                      value: '${patch.converted}',
                      label: 'Converted',
                      color: p.go,
                    ),
                    FigureChip(
                      icon: Iconsax.call,
                      value: '${patch.calls}',
                      label: 'Calls',
                      color: p.primary,
                    ),
                    FigureChip(
                      icon: Iconsax.people,
                      value: '${patch.reps}',
                      label: 'Reps',
                      color: p.info,
                    ),
                  ],
                ),
                if (patch.categories.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.m),
                  Text(
                    [
                      for (final category in patch.categories)
                        '${category.categoryName}  ${category.calls} calls',
                    ].join('  ·  '),
                    style: text.bodySmall?.copyWith(color: p.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/unlisted_patch_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/unlisted.dart';
import '../../services/auth_service.dart';
import '../visits/unlisted_detail_sheet.dart';

/// The unlisted doctors and chemists of one patch, with their calls, and the action to flag one as converted.
class UnlistedPatchView extends GetView<UnlistedPatchController> {
  const UnlistedPatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          controller.args.patch.subzoneName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
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

  Widget _body(BuildContext context, double gutter) {
    if (controller.isLoading) return const LoadingList(count: 4);
    final error = controller.errorMessage;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Could not load this patch',
        message: error,
      );
    }
    if (controller.contacts.isEmpty) {
      return const EmptyState(
        icon: Iconsax.user,
        title: 'No unlisted contacts here',
        message: 'Nobody was met off the list in this patch in this period.',
      );
    }
    final canConvert = Get.find<AuthService>().can('contacts.manage');
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.all(gutter),
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.lg,
              boxShadow: AppEffects.card(p),
              border: AppEffects.hairline(p),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.lg,
              child: Column(
                children: [
                  for (var i = 0; i < controller.contacts.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    InkWell(
                      onTap: () => showUnlistedDetail(
                        context,
                        controller.contacts[i].unlistedId,
                      ),
                      child: _ContactStatRow(
                        stat: controller.contacts[i],
                        onConvert: canConvert
                            ? () => _convert(context, controller.contacts[i])
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _convert(BuildContext context, UnlistedContactStat stat) async {
    final confirmed = await AppDialogs.confirm(
      title: 'Mark ${stat.name} as converted?',
      message: 'Past calls stay on this record. Add them to the contact list yourself, so new calls go to that listed contact.',
      confirmLabel: 'Mark converted',
    );
    if (!confirmed) return;
    final problem = await controller.convert(stat);
    if (problem != null && context.mounted) {
      await AppDialogs.error('Could not mark as converted', problem);
    }
  }
}

/// One unlisted contact: its name and kind, the calls and reps on it, and the status or the action to convert it.
class _ContactStatRow extends StatelessWidget {
  const _ContactStatRow({required this.stat, this.onConvert});

  final UnlistedContactStat stat;
  final VoidCallback? onConvert;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final last = stat.lastVisit;
    final details = [
      '${stat.calls} ${stat.calls == 1 ? 'call' : 'calls'}',
      '${stat.reps} ${stat.reps == 1 ? 'rep' : 'reps'}',
      if (last != null) 'last ${formatDay(last)}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.m,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.name,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${stat.categoryName}  ·  $details',
                  style: text.bodySmall?.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
          if (stat.isConverted)
            Text(
              'Converted',
              style: text.labelLarge?.copyWith(
                color: p.go,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (onConvert != null)
            TextButton(
              onPressed: onConvert,
              child: const Text('Mark converted'),
            ),
        ],
      ),
    );
  }
}

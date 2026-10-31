import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/performance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_feedback.dart';
import '../../core/utils/business_time.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/member_report.dart';
import 'member_detail_view.dart';

/// Team performance for a chosen period: a row per person, with a copy-as-CSV export and a page for each person.
class PerformanceView extends GetView<PerformanceController> {
  const PerformanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.l,
            AppSpace.s,
            AppSpace.l,
            AppSpace.m,
          ),
          child: _PeriodBar(controller: controller),
        ),
        Expanded(child: Obx(() => _body(context))),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading.value) return const LoadingList(count: 3);
    final error = controller.loadError.value;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Report unavailable',
        message: error,
      );
    }
    if (controller.members.isEmpty) {
      return const EmptyState(
        icon: Iconsax.chart_2,
        title: 'No one to report on',
        message: 'Team members appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.l,
          0,
          AppSpace.l,
          AppSpace.xxl,
        ),
        itemCount: controller.members.length,
        itemBuilder: (context, index) =>
            _MemberTile(row: controller.members[index], controller: controller),
      ),
    );
  }
}

/// The period presets, a custom range, and the export. The chosen dates show under them.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.controller});

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpace.s,
                runSpacing: AppSpace.s,
                children: [
                  for (final (value, label) in const [
                    (PerformancePeriod.thisMonth, 'This month'),
                    (PerformancePeriod.lastMonth, 'Last month'),
                    (PerformancePeriod.last30Days, 'Last 30 days'),
                    (PerformancePeriod.custom, 'Custom'),
                  ])
                    Obx(
                      () => ChoiceChip(
                        label: Text(label),
                        selected: controller.period.value == value,
                        onSelected: (_) => value == PerformancePeriod.custom
                            ? _pickRange(context)
                            : controller.choose(value),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy as CSV',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: controller.toCsv()),
                );
                showAppMessage(
                  'Copied',
                  'The table is on the clipboard as CSV.',
                );
              },
              icon: Icon(Iconsax.document_download, color: p.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s),
        Obx(
          () => Text(
            '${formatDay(controller.from.value)} to ${formatDay(controller.to.value)}',
            style: text.bodySmall?.copyWith(color: p.inkMuted),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final today = indiaToday();
    final range = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: controller.from.value,
        end: controller.to.value,
      ),
    );
    if (range != null) controller.setCustomRange(range);
  }
}

/// One person: their name and role, and the figures that matter for the period.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.row, required this.controller});

  final MemberRow row;
  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final reports = row.daysNeverReported > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lg,
          boxShadow: AppEffects.card(p),
        ),
        child: Material(
          color: p.surface,
          borderRadius: AppRadius.lg,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => Get.toNamed(
              AppRoutes.memberDetail,
              arguments: MemberDetailArgs(
                userId: row.userId,
                name: row.fullName,
                from: controller.from.value,
                to: controller.to.value,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(
              AppSpace.l,
              AppSpace.s,
              AppSpace.s,
              AppSpace.s,
            ),
            title: Text(
              row.fullName,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                [
                  row.roleName,
                  '${row.calls} ${row.calls == 1 ? 'call' : 'calls'}',
                  if (row.coverageTotal > 0)
                    '${(row.coverage * 100).round()}% covered',
                  if (row.plansDue > 0)
                    '${row.plansAchieved} of ${row.plansDue} plans',
                  if (reports) '${row.daysNeverReported} days never reported',
                ].join('  ·  '),
                style: text.bodySmall?.copyWith(
                  color: reports ? p.alert : p.inkMuted,
                ),
              ),
            ),
            trailing: const Icon(Iconsax.arrow_right_3, size: 16),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/complete_day_controller.dart';
import '../../controllers/visit_record_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/business_time.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/month_calendar.dart';
import '../../models/visit.dart';
import '../../models/contact.dart';

/// The top half is a calendar of the days still open for reporting. The bottom half is the selected day.
class CompleteDayView extends GetView<CompleteDayController> {
  const CompleteDayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.l,
            0,
            AppSpace.l,
            AppSpace.m,
          ),
          child: Obx(() => _calendar(context)),
        ),
        Expanded(child: Obx(() => _dayBody(context))),
      ],
    );
  }

  Widget _calendar(BuildContext context) {
    final p = context.palette;
    final markers = <DateTime, List<Color>>{};
    for (
      var date = controller.firstDate;
      !date.isAfter(controller.lastDate);
      date = date.add(const Duration(days: 1))
    ) {
      markers[date] = [_colourOf(p, controller.statusOn(date))];
    }
    return MonthCalendar(
      selected: controller.selectedDate.value,
      firstDate: controller.firstDate,
      lastDate: controller.lastDate,
      markers: markers,
      legend: [
        ('Completed', p.go),
        ('Open', p.warning),
        ('Today', p.info),
        ('Not reported', p.alert),
        ('Closed', p.inkMuted),
        ('Leave', p.accent),
      ],
      onSelected: controller.selectDate,
    );
  }

  Widget _dayBody(BuildContext context) {
    if (controller.isLoading.value)
      return const Center(child: CircularProgressIndicator());
    final error = controller.loadError.value;
    if (error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Text(error),
        ),
      );
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.l,
          0,
          AppSpace.l,
          AppSpace.xxl,
        ),
        children: [
          if (controller.jointRequests.isNotEmpty) ...[
            _JointSection(controller: controller),
            const SizedBox(height: AppSpace.l),
          ],
          _DayHeader(controller: controller),
          const SizedBox(height: AppSpace.m),
          ..._visitRows(context),
        ],
      ),
    );
  }

  List<Widget> _visitRows(BuildContext context) {
    final date = controller.selectedDate.value;
    final visits = controller.visitsOn(date);
    if (visits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
          child: Text(
            controller.statusOn(date) == DayStatus.notReported
                ? 'Nothing was recorded on this day.'
                : 'No calls recorded for this day yet.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.palette.inkMuted),
          ),
        ),
      ];
    }
    return [
      _ListPanel(
        children: [
          for (final visit in visits)
            _VisitRow(visit: visit, controller: controller),
        ],
      ),
    ];
  }

  static Color _colourOf(AppPalette p, DayStatus status) => switch (status) {
    DayStatus.completed => p.go,
    DayStatus.open => p.warning,
    DayStatus.today => p.info,
    DayStatus.notReported => p.alert,
    DayStatus.missed => p.inkMuted,
    DayStatus.leave => p.accent,
  };
}

/// Joint calls other reps recorded with this rep. Each is accepted, or disputed, here.
class _JointSection extends StatelessWidget {
  const _JointSection({required this.controller});

  final CompleteDayController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Joint calls waiting for you',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpace.m),
        _ListPanel(
          children: [
            for (final request in controller.jointRequests)
              Padding(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.contactName,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '${formatDay(request.visitDate)} · ${request.subzoneName}',
                      style: text.bodySmall?.copyWith(color: p.inkMuted),
                    ),
                    const SizedBox(height: AppSpace.m),
                    if (request.canRespond)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.isBusy.value
                                  ? null
                                  : () => _answer(
                                      context,
                                      request,
                                      accept: false,
                                    ),
                              child: const Text('Dispute'),
                            ),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: FilledButton(
                              onPressed: controller.isBusy.value
                                  ? null
                                  : () =>
                                        _answer(context, request, accept: true),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _statusLabel(request.status),
                        style: text.bodySmall?.copyWith(color: p.inkMuted),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _answer(
    BuildContext context,
    JointRequest request, {
    required bool accept,
  }) async {
    final problem = await controller.answerJoint(request, accept: accept);
    if (problem != null) await AppDialogs.error('Could not answer', problem);
  }

  static String _statusLabel(String status) => switch (status) {
    'accepted' => 'Accepted',
    'disputed' => 'Disputed',
    _ => 'Waiting for an answer',
  };
}

/// A card-free list surface: rows separated by hairlines, as in the contacts list.
class _ListPanel extends StatelessWidget {
  const _ListPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
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
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The selected day's status, and the button that closes it.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.controller});

  final CompleteDayController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final date = controller.selectedDate.value;
    final status = controller.statusOn(date);
    final canEnd = controller.canEndOn(date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDay(date),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                _statusText(date, status),
                style: text.bodySmall?.copyWith(color: p.inkMuted),
              ),
            ],
          ),
        ),
        if (controller.canReleaseLeaveOn(date))
          FilledButton(
            onPressed: controller.isBusy.value
                ? null
                : () => _removeLeave(context, date),
            child: const Text('Remove leave'),
          )
        else if (canEnd)
          FilledButton(
            onPressed: controller.isBusy.value
                ? null
                : () => _endDay(context, date),
            child: const Text('End day'),
          ),
      ],
    );
  }

  String _statusText(DateTime date, DayStatus status) => switch (status) {
    DayStatus.completed => 'Day ended. Its calls are final.',
    DayStatus.open => 'Open. End it when the calls are done.',
    DayStatus.today => 'Today. Record calls as you go.',
    DayStatus.notReported =>
      'Not reported. Report by ${formatDay(controller.reportBy(date))}.',
    DayStatus.missed =>
      'Closed. The report window has passed, so this day is read only.',
    DayStatus.leave =>
      isSunday(date)
          ? 'Sunday is a leave day for everyone.'
          : 'Marked as leave. Remove the leave to report calls on this day.',
  };

  /// A leave day is released before calls can be reported on it. The rep confirms first, or cancels.
  Future<void> _removeLeave(BuildContext context, DateTime date) async {
    final confirmed = await AppDialogs.confirm(
      title: 'Remove leave for ${formatDay(date)}?',
      message: 'You will be able to report calls on this day again.',
      confirmLabel: 'Remove leave',
    );
    if (!confirmed) return;
    final problem = await controller.removeLeave(date);
    if (problem != null)
      await AppDialogs.error('Could not remove the leave', problem);
  }

  Future<void> _endDay(BuildContext context, DateTime date) async {
    final confirmed = await AppDialogs.confirm(
      title: 'End ${formatDay(date)}?',
      message: 'Its calls are completed and cannot be changed after this.',
      confirmLabel: 'End day',
    );
    if (!confirmed) return;
    final problem = await controller.endDay(date);
    if (problem != null)
      await AppDialogs.error('Could not end the day', problem);
  }
}

/// One recorded call on the selected day: the time, the contact, the products, and the remarks in one line.
/// It can be changed or deleted only while its day is open.
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.controller});

  final VisitRecord visit;
  final CompleteDayController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final products = visit.products.map((product) => product.name).join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.m,
        AppSpace.s,
        AppSpace.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              visit.visitTime.substring(0, 5),
              style: text.labelLarge?.copyWith(color: p.inkMuted),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.contactName,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  contactKind(visit.categoryName, visit.typeName),
                  style: text.bodySmall?.copyWith(
                    color: p.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(products, style: text.bodySmall?.copyWith(color: p.ink)),
                Text(
                  visit.remarks,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: p.inkMuted),
                ),
                if (visit.partnerUserId != null)
                  Text(
                    'Joint call · ${visit.partnerStatus ?? 'pending'}',
                    style: text.labelSmall?.copyWith(
                      color: p.inkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (visit.isEditable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit call',
                  visualDensity: VisualDensity.compact,
                  onPressed: _edit,
                  icon: Icon(Iconsax.edit_2, size: 18, color: p.primary),
                ),
                IconButton(
                  tooltip: 'Delete call',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.isBusy.value
                      ? null
                      : () => _delete(context),
                  icon: Icon(Iconsax.trash, size: 18, color: p.alert),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    await Get.toNamed(
      AppRoutes.visitRecord,
      arguments: VisitRecordArgs(contact: visit.contact, visit: visit),
    );
    await controller.load();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      title: 'Delete this call?',
      message: 'It is removed from the day. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final problem = await controller.deleteVisit(visit);
    if (problem != null) await AppDialogs.error('Could not delete', problem);
  }
}

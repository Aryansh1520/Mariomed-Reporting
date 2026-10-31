import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../controllers/home_controller.dart';
import '../../core/utils/business_time.dart';
import '../../controllers/plan_day_controller.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../models/report.dart';
import '../../services/api_service.dart';
import '../../services/plan_service.dart';
import '../../services/app_exception.dart';
import '../../services/report_service.dart';

/// One full report: its figures at the top, then each list with its own empty state.
/// The kind arrives as the route argument, from the home card that was tapped.
class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  late final ReportKind _kind = Get.arguments as ReportKind;
  late Future<ReportData> _report = _load();

  Future<ReportData> _load() =>
      ReportService(Get.find<ApiService>()).load(_kind);

  Future<void> _refresh() async {
    setState(() => _report = _load());
    await _report;
  }

  /// Plans a contact for today, from the Missed report. The plan rules (leave day, duplicates) are checked by the server.
  Future<void> _planToday(ReportRow row) async {
    final id = row.contactId;
    if (id == null) return;
    try {
      await PlanService(Get.find<ApiService>()).addItem(indiaToday(), id);
    } on AppException catch (e) {
      await AppDialogs.error('Could not plan this call', e.message);
      return;
    }
    if (Get.isRegistered<PlanDayController>())
      Get.find<PlanDayController>().load();
    if (Get.isRegistered<HomeController>())
      Get.find<HomeController>().loadDashboard();
    await AppDialogs.success(
      'Added to today’s plan',
      '${row.title} is planned for today.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(reportTitle(_kind))),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: FutureBuilder<ReportData>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingList(count: 3);
              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is AppException
                    ? error.message
                    : 'Could not load this report.';
                return EmptyState(
                  icon: Iconsax.warning_2,
                  title: 'Report unavailable',
                  message: message,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: _ReportBody(
                  data: snapshot.data!,
                  gutter: AppLayout.gutter(size),
                  onPlanToday: _kind == ReportKind.missed ? _planToday : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static String reportTitle(ReportKind kind) => switch (kind) {
    ReportKind.today => 'Today',
    ReportKind.month => 'This month',
    ReportKind.coverage => 'Coverage',
    ReportKind.missed => 'Missed',
    ReportKind.calls => 'Calls, last 14 days',
    ReportKind.nextUp => 'Next up',
    ReportKind.joint => 'Joint calls',
    ReportKind.team => 'Team',
  };
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.data,
    required this.gutter,
    this.onPlanToday,
  });

  final ReportData data;
  final double gutter;

  /// Shown beside each row that names a contact. Null when the report cannot plan.
  final ValueChanged<ReportRow>? onPlanToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.s, gutter, AppSpace.xxl),
      children: [
        Row(
          children: [
            for (final figure in data.figures)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      figure.value,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _toneColour(p, figure.tone),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      figure.label,
                      style: text.bodySmall?.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (data.footnote != null) ...[
          const SizedBox(height: AppSpace.m),
          Text(
            data.footnote!,
            style: text.bodySmall?.copyWith(color: p.inkMuted),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        for (final section in data.sections) ...[
          _SectionList(section: section, onPlanToday: onPlanToday),
          const SizedBox(height: AppSpace.l),
        ],
      ],
    );
  }

  static Color _toneColour(AppPalette p, RowTone tone) => switch (tone) {
    RowTone.good => p.go,
    RowTone.warning => p.warning,
    RowTone.alert => p.alert,
    RowTone.muted => p.inkMuted,
    RowTone.normal => p.ink,
  };
}

/// One list in a surface panel, rows separated by hairlines. An empty list says why it is empty.
class _SectionList extends StatelessWidget {
  const _SectionList({required this.section, this.onPlanToday});

  final ReportSection section;
  final ValueChanged<ReportRow>? onPlanToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final header = Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: Text(
        section.title,
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    if (section.rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Text(
            section.emptyText,
            style: text.bodyMedium?.copyWith(color: p.inkMuted),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
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
                for (var i = 0; i < section.rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  _ReportRowTile(
                    row: section.rows[i],
                    onPlanToday: onPlanToday,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportRowTile extends StatelessWidget {
  const _ReportRowTile({required this.row, this.onPlanToday});

  final ReportRow row;
  final ValueChanged<ReportRow>? onPlanToday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tone = switch (row.tone) {
      RowTone.good => p.go,
      RowTone.warning => p.warning,
      RowTone.alert => p.alert,
      RowTone.muted => p.inkMuted,
      RowTone.normal => p.inkMuted,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.m,
        AppSpace.l,
        AppSpace.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (row.subtitle != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    row.subtitle!,
                    style: text.bodySmall?.copyWith(color: p.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          if (row.trailing != null) ...[
            const SizedBox(width: AppSpace.s),
            Text(
              row.trailing!,
              style: text.labelMedium?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onPlanToday != null && row.contactId != null) ...[
            const SizedBox(width: AppSpace.s),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onPlanToday!(row),
              child: const Text('Plan today'),
            ),
          ],
        ],
      ),
    );
  }
}

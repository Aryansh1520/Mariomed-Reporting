import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/team_dashboard_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/home_graphs.dart';
import '../../models/team_dashboard.dart';
import 'team_day_view.dart';
import 'member_detail_view.dart';

/// The team-wide sections for the month: the summary, calls per day, then employees, zones, products and categories.
/// Averages are per working day; Sundays, holidays and leave are not counted. Shown on Home for admin.dashboard.
class TeamDashboardSections extends StatelessWidget {
  const TeamDashboardSections({super.key, required this.dashboard});

  final TeamDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final data = dashboard;
    final summary = data.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(summary: summary),
        const SizedBox(height: AppSpace.l),
        _Panel(
          title: 'Calls per day',
          child: _CallsPerDay(days: data.daily),
        ),
        const SizedBox(height: AppSpace.l),
        _SectionCard(
          icon: Iconsax.user,
          tone: _Tone.blue,
          title: 'Employees',
          trailing: '${data.employees.length} reps',
          empty: 'No employee reports their calls yet.',
          children: [
            for (final (index, line) in data.employees.indexed)
              _PersonRow(
                line: line,
                tone: index.isEven ? _Tone.blue : _Tone.purple,
                onTap: () => _openMember(line),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        _SectionCard(
          icon: Iconsax.location,
          tone: _Tone.green,
          title: 'Zones',
          trailing: '${data.zones.length} zones',
          empty: 'No zones yet.',
          children: [
            for (final line in data.zones)
              _ZoneRow(line: line, onTap: () => _openZone(line)),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        _SectionCard(
          icon: Iconsax.box,
          tone: _Tone.orange,
          title: 'Products',
          trailing: '${data.products.length} products',
          onManage: () => Get.toNamed(AppRoutes.products),
          empty: 'No products were shared on calls in this period.',
          children: [
            for (final (index, line) in data.products.indexed)
              _ProductRow(
                line: line,
                tone: index.isEven ? _Tone.blue : _Tone.purple,
                onTap: () => Get.to(
                  () => ProductStatsView(
                    productId: line.productId,
                    name: line.name,
                    stat: line,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        _SectionCard(
          icon: Iconsax.category,
          tone: _Tone.purple,
          title: 'Categories',
          trailing: '${data.categories.length} categories',
          onManage: () => Get.toNamed(AppRoutes.categories),
          empty: 'No calls recorded in this period.',
          children: [
            for (final line in data.categories)
              _CategoryRow(
                line: line,
                onTap: () => Get.to(
                  () => CategoryStatsView(
                    categoryName: line.categoryName,
                    stat: line,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// One person's performance over the same period as the dashboard.
  void _openMember(EmployeeLine line) {
    final team = Get.find<TeamDashboardController>();
    Get.toNamed(
      AppRoutes.memberDetail,
      arguments: MemberDetailArgs(
        userId: line.userId,
        name: line.fullName,
        from: team.from.value,
        to: team.to.value,
      ),
    );
  }

  /// One zone over the dashboard's period.
  void _openZone(ZoneLine zone) {
    final team = Get.find<TeamDashboardController>();
    Get.to(
      () =>
          ZoneDetailView(zone: zone, from: team.from.value, to: team.to.value),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

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
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          child,
        ],
      ),
    );
  }
}

/// Two columns of metric tiles, so the grid reads as a table of figures.
/// Calls per day as stacked columns: calls in the primary blue, missed calls on top in the alert red,
/// with a 2px gap between. Each column explains itself on hover; the first and last day are labelled under the axis.
class _CallsPerDay extends StatelessWidget {
  const _CallsPerDay({required this.days});

  final List<DayPoint> days;

  static const _height = 140.0;
  static const _barArea = 136.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    if (days.isEmpty) return const SizedBox.shrink();
    final peak = days.fold<int>(
      1,
      (max, day) =>
          day.calls + day.missedCalls > max ? day.calls + day.missedCalls : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: GestureDetector(
                    onTap: () => Get.to(
                      () => TeamDayView(day: day.day, first: days.first.day),
                    ),
                    child: Tooltip(
                      message:
                          '${day.day.day}/${day.day.month}: ${day.calls} calls, ${day.missedCalls} missed calls',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (day.missedCalls > 0)
                              Container(
                                height: _barArea * day.missedCalls / peak,
                                decoration: BoxDecoration(
                                  color: p.alert,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            if (day.missedCalls > 0 && day.calls > 0)
                              const SizedBox(height: 2),
                            if (day.calls > 0)
                              Container(
                                height: _barArea * day.calls / peak,
                                decoration: BoxDecoration(
                                  color: p.primary,
                                  borderRadius: day.missedCalls > 0
                                      ? BorderRadius.zero
                                      : const BorderRadius.vertical(
                                          top: Radius.circular(3),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
        const SizedBox(height: AppSpace.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${days.first.day.day}/${days.first.day.month}',
              style: text.bodySmall?.copyWith(color: p.inkMuted),
            ),
            Text(
              '${days.last.day.day}/${days.last.day.month}',
              style: text.bodySmall?.copyWith(color: p.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        Row(
          children: [
            _Key(color: p.primary, label: 'Calls'),
            const SizedBox(width: AppSpace.l),
            _Key(color: p.alert, label: 'Missed calls'),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: AppRadius.sm),
        ),
        const SizedBox(width: AppSpace.xs),
        Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
      ],
    );
  }
}

/// A headline figure: the largest type on the panel, with its label beneath.

/// The team's headline figures: calls and missed calls, contact coverage with its bar, then the secondary stats.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final TeamSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final coverage = summary.coveragePercent / 100;
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Summary',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.m,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  'Performance',
                  style: text.labelMedium?.copyWith(color: p.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          Row(
            children: [
              Expanded(
                child: _FigureTile(
                  value: '${summary.calls}',
                  label: 'Calls',
                  color: p.ink,
                  tint: p.primary.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: _FigureTile(
                  value: '${summary.missedCalls}',
                  label: 'Missed calls',
                  color: p.alert,
                  tint: p.alert.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          Container(
            padding: const EdgeInsets.all(AppSpace.l),
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: AppRadius.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact coverage',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                ),
                const SizedBox(height: AppSpace.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CoverageRing(
                      percent: coverage,
                      color: p.primary,
                      track: p.border,
                      size: 84,
                    ),
                    const SizedBox(width: AppSpace.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${summary.contactsVisited} of ${summary.coverageTotal}',
                            textAlign: TextAlign.center,
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'Contacts visited',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.m),
                ClipRRect(
                  borderRadius: AppRadius.pill,
                  child: LinearProgressIndicator(
                    value: coverage,
                    minHeight: 8,
                    color: p.primary,
                    backgroundColor: p.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.l),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: AppRadius.md,
            ),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.l),
                          child: _Stat(
                            label: 'Per working day',
                            value: summary.avgCallsPerDay.toStringAsFixed(1),
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: p.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.l),
                          child: _Stat(
                            label: 'Working days',
                            value: '${summary.workingDays}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: p.border),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.l),
                          child: _Stat(
                            label: 'Planned achieved',
                            value:
                                '${summary.plannedAchieved} of ${summary.plannedDue}',
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: p.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.l),
                          child: _Stat(
                            label: 'Reporting employees',
                            value: '${summary.reportingReps}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FigureTile extends StatelessWidget {
  const _FigureTile({
    required this.value,
    required this.label,
    required this.color,
    required this.tint,
  });

  final String value;
  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(color: tint, borderRadius: AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(label, style: text.bodyMedium?.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: p.inkMuted),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          value,
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
      ],
    );
  }
}

/// Accent colours for the list sections and rows. Each tone is a colour and its light tint.
enum _Tone {
  blue(Color(0xFF1F5FDB), Color(0xFFE6EEFB)),
  green(Color(0xFF1E9E5A), Color(0xFFE2F4EA)),
  orange(Color(0xFFE8871E), Color(0xFFFDEEDC)),
  purple(Color(0xFF7B5CE0), Color(0xFFEEE9FD)),
  red(Color(0xFFE5484D), Color(0xFFFBE4E4));

  const _Tone(this.color, this.tint);

  final Color color;
  final Color tint;
}

/// One list section: a tinted icon well, the title and the count, then its first two rows.
/// A show-more button opens the full list on its own page.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.onManage,
    required this.icon,
    required this.tone,
    required this.title,
    required this.trailing,
    required this.empty,
    required this.children,
  });

  final IconData icon;
  final _Tone tone;
  final String title;
  final String trailing;
  final String empty;
  final VoidCallback? onManage;
  final List<Widget> children;

  static const _preview = 2;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final shown = children.take(_preview).toList();
    final hidden = children.length - shown.length;
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
                  color: tone.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: tone.color),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              Text(
                trailing,
                style: text.bodyMedium?.copyWith(color: p.inkMuted),
              ),
              if (onManage != null)
                TextButton(onPressed: onManage, child: const Text('Manage')),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          if (children.isEmpty)
            Text(empty, style: text.bodyMedium?.copyWith(color: p.inkMuted))
          else ...[
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.m),
              shown[i],
            ],
            if (hidden > 0) ...[
              const SizedBox(height: AppSpace.s),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Get.to(
                    () => TeamSectionPage(
                      title: title,
                      rows: children,
                      onManage: onManage,
                    ),
                  ),
                  child: Text('Show more ($hidden more)'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Every row of one dashboard section, on its own page.
class TeamSectionPage extends StatelessWidget {
  const TeamSectionPage({
    super.key,
    required this.title,
    required this.rows,
    this.onManage,
  });

  final String title;
  final List<Widget> rows;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final size = AppLayout.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
        actions: [
          if (onManage != null)
            IconButton(
              tooltip: 'Manage',
              onPressed: onManage,
              icon: const Icon(Iconsax.setting_2),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: ListView(
            padding: EdgeInsets.all(AppLayout.gutter(size)),
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.m),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// A coloured figure: a tinted square with its icon, the value in bold and its label beneath.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    this.valueColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final _Tone tone;
  final Color? valueColor;

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
            color: tone.tint,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, size: 16, color: tone.color),
        ),
        const SizedBox(width: AppSpace.s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor ?? p.ink,
              ),
            ),
            Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
          ],
        ),
      ],
    );
  }
}

/// A thin vertical rule between figures on one row.
class _RuleDivider extends StatelessWidget {
  const _RuleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.m),
      color: context.palette.border,
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.line,
    required this.tone,
    required this.onTap,
  });

  final EmployeeLine line;
  final _Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final initials = line.fullName
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return _RowCard(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 96,
              alignment: Alignment.center,
              color: tone.tint.withValues(alpha: 0.6),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: p.surface,
                child: Text(
                  initials,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tone.color,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.fullName,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      '${line.avgCallsPerDay.toStringAsFixed(1)} per working day',
                      style: text.bodySmall?.copyWith(color: p.inkMuted),
                    ),
                    const SizedBox(height: AppSpace.m),
                    Row(
                      children: [
                        _Metric(
                          icon: Iconsax.call,
                          value: '${line.calls}',
                          label: 'Calls',
                          tone: _Tone.blue,
                        ),
                        const _RuleDivider(),
                        _Metric(
                          icon: Iconsax.call_remove,
                          value: '${line.missedCalls}',
                          label: 'Missed',
                          tone: _Tone.red,
                          valueColor: _Tone.red.color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.m),
              child: Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.line, required this.onTap});

  final ZoneLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final fraction = line.coveragePercent / 100;
    return _RowCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _Tone.blue.tint,
                borderRadius: AppRadius.md,
              ),
              child: Icon(Iconsax.location, size: 24, color: _Tone.blue.color),
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
                          line.zoneName,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.m,
                          vertical: AppSpace.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _Tone.blue.tint,
                          borderRadius: AppRadius.pill,
                        ),
                        child: Text(
                          '${line.coveragePercent.toStringAsFixed(1)}%',
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _Tone.blue.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${line.contactsVisited} of ${line.coverageTotal} contacts visited',
                    style: text.bodySmall?.copyWith(color: p.inkMuted),
                  ),
                  const SizedBox(height: AppSpace.s),
                  ClipRRect(
                    borderRadius: AppRadius.pill,
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      color: _Tone.blue.color,
                      backgroundColor: p.border,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.line,
    required this.tone,
    required this.onTap,
  });

  final ProductLine line;
  final _Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return _RowCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.tint,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(Iconsax.box, size: 32, color: tone.color),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Wrap(
                      spacing: AppSpace.m,
                      runSpacing: AppSpace.s,
                      children: [
                        _Metric(
                          icon: Iconsax.call,
                          value: '${line.calls}',
                          label: 'Calls',
                          tone: _Tone.blue,
                        ),
                        _Metric(
                          icon: Iconsax.people,
                          value: '${line.contactsVisited}',
                          label: 'Contacts',
                          tone: _Tone.purple,
                        ),
                        _Metric(
                          icon: Iconsax.user,
                          value: '${line.reps}',
                          label: 'Reps',
                          tone: _Tone.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.line, required this.onTap});

  final CategoryLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return _RowCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.categoryName,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s),
                  Row(
                    children: [
                      _Metric(
                        icon: Iconsax.call,
                        value: '${line.calls}',
                        label: 'Calls',
                        tone: _Tone.blue,
                      ),
                      const _RuleDivider(),
                      _Metric(
                        icon: Iconsax.people,
                        value: '${line.contactsVisited}',
                        label: 'Contacts',
                        tone: _Tone.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../app/routes/app_routes.dart';
import '../../models/dashboard.dart';
import '../../models/report.dart';

import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

/// The short cards under the hero. Each card is drawn only when the server sent its data.
class DashboardSections extends StatelessWidget {
  const DashboardSections({super.key, required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (dashboard.today != null) _TodayCard(stats: dashboard.today!),
      if (dashboard.missed != null) _MissedCard(stats: dashboard.missed!),
      if (dashboard.nextUp != null) _NextUpCard(items: dashboard.nextUp!),
      if (dashboard.jointWaiting != null && dashboard.jointWaiting! > 0)
        _JointCard(count: dashboard.jointWaiting!),
      if (dashboard.team != null) _TeamCard(stats: dashboard.team!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in cards) ...[card, const SizedBox(height: AppSpace.m)],
      ],
    );
  }
}

/// A short card: a quiet title and its content. The only surface on the page.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, required this.report});

  final String title;
  final Widget child;

  /// The full report this card opens.
  final ReportKind report;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.report, arguments: report),
      child: Container(
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
                    title,
                    style: text.labelLarge?.copyWith(
                      color: p.inkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
              ],
            ),
            const SizedBox(height: AppSpace.s),
            child,
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.stats});

  final TodayStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final status = stats.isLeave == true
        ? 'On leave'
        : switch (stats.dayStatus) {
            'ended' => 'Day ended',
            'open' => 'Day open',
            _ => 'No report yet',
          };
    final planned = stats.planned == null ? null : '${stats.planned} planned';
    return _Card(
      title: 'Today',
      report: ReportKind.today,
      child: Row(
        children: [
          Text(
            '${stats.calls}',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Text(
            stats.calls == 1 ? 'call' : 'calls',
            style: text.bodyMedium?.copyWith(color: p.inkMuted),
          ),
          const Spacer(),
          Text(
            planned == null ? status : '$status · $planned',
            style: text.bodySmall?.copyWith(
              color: p.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({required this.stats});

  final MissedStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Card(
      title: 'Missed',
      report: ReportKind.missed,
      child: _Figure(
        value: '${stats.missedContacts}',
        label: 'contacts not visited this month',
        colour: stats.missedContacts > 0 ? p.alert : null,
      ),
    );
  }
}

/// The next three planned calls. Anything further out is in Tasks.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.items});

  final List<NextUpItem> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final shown = items.take(3).toList();
    return _Card(
      title: 'Next up',
      report: ReportKind.nextUp,
      child: shown.isEmpty
          ? Text(
              'Nothing planned for the next 7 days.',
              style: text.bodyMedium?.copyWith(color: p.inkMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            formatDay(item.planDate)
                                .replaceAll(RegExp(r' \d{4}$'), ''),
                            style: text.labelSmall?.copyWith(color: p.inkMuted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.contactName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.stats});

  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Team',
      report: ReportKind.team,
      child: _Figure(value: '${stats.activeUsers}', label: 'active people'),
    );
  }
}

class _JointCard extends StatelessWidget {
  const _JointCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return _Card(
      title: 'Joint calls',
      report: ReportKind.joint,
      child: Text(
        '$count waiting for your answer in Tasks.',
        style: text.bodyMedium?.copyWith(
          color: p.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A figure and its label.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.colour});

  final String value;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colour ?? p.ink,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
      ],
    );
  }
}

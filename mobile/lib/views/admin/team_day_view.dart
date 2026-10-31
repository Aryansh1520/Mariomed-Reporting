import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/business_time.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/team_dashboard.dart';
import '../../services/api_service.dart';
import '../../services/app_exception.dart';
import '../../services/team_dashboard_service.dart';

/// Everything the team did on one day, with previous and next day arrows. Never goes past today.
class TeamDayView extends StatefulWidget {
  const TeamDayView({super.key, required this.day, required this.first});

  /// The day that was tapped.
  final DateTime day;

  /// The earliest day the arrows can reach: the first day of the chart.
  final DateTime first;

  @override
  State<TeamDayView> createState() => _TeamDayViewState();
}

class _TeamDayViewState extends State<TeamDayView> {
  late DateTime _day = widget.day;
  late Future<_DayFigures> _figures = _load();

  Future<_DayFigures> _load() async {
    final service = TeamDashboardService(Get.find<ApiService>());
    final dashboard = await service.fetch(from: _day, to: _day);
    final calls = await service.fetchCalls(from: _day, to: _day);
    final missed = await service.fetchMissed(_day);
    return _DayFigures(dashboard: dashboard, calls: calls, missed: missed);
  }

  void _move(int by) {
    setState(() {
      _day = _day.add(Duration(days: by));
      _figures = _load();
    });
  }

  /// Opens a date picker from the first day of the chart up to today, and shows the day picked.
  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: widget.first,
      lastDate: indiaToday(),
    );
    if (picked == null) return;
    setState(() {
      _day = DateUtils.dateOnly(picked);
      _figures = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final size = AppLayout.sizeOf(context);
    final today = indiaToday();
    final canBack = _day.isAfter(widget.first);
    final canForward = _day.isBefore(today);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Day summary',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.gutter(size),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous day',
                      onPressed: canBack ? () => _move(-1) : null,
                      icon: const Icon(Iconsax.arrow_left_2),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: AppRadius.sm,
                        onTap: () => _pickDay(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatDay(_day),
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Icon(
                                Iconsax.calendar_1,
                                size: 18,
                                color: p.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next day',
                      onPressed: canForward ? () => _move(1) : null,
                      icon: const Icon(Iconsax.arrow_right_2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<_DayFigures>(
                  future: _figures,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingList(count: 3);
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return EmptyState(
                        icon: Iconsax.warning_2,
                        title: 'Could not load this day',
                        message: error is AppException
                            ? error.message
                            : 'Try again in a moment.',
                      );
                    }
                    return _DayBody(
                      figures: snapshot.data!,
                      gutter: AppLayout.gutter(size),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayFigures {
  const _DayFigures({
    required this.dashboard,
    required this.calls,
    required this.missed,
  });

  final TeamDashboard dashboard;
  final List<TeamCallLine> calls;
  final List<MissedContact> missed;
}

/// Colour pairs, the same as the person page: blue for calls, purple for contacts, red for missed.
class _Accent {
  const _Accent(this.color, this.tint);

  final Color color;
  final Color tint;

  static const blue = _Accent(Color(0xFF1F5FDB), Color(0xFFE6EEFB));
  static const green = _Accent(Color(0xFF1E9E5A), Color(0xFFE2F4EA));
  static const red = _Accent(Color(0xFFE5484D), Color(0xFFFBE4E4));
  static const purple = _Accent(Color(0xFF7B5CE0), Color(0xFFEEE9FD));
}

/// The day's figures in one card, then every call made that day, in the same style as the person page.
/// The sections of the day page. Only one is expanded at a time.
enum _DaySection { calls, missed }

class _DayBody extends StatefulWidget {
  const _DayBody({required this.figures, required this.gutter});

  final _DayFigures figures;
  final double gutter;

  @override
  State<_DayBody> createState() => _DayBodyState();
}

class _DayBodyState extends State<_DayBody> {
  /// Calls start expanded. Opening one section closes the other; tapping the open one closes it.
  _DaySection? _open = _DaySection.calls;

  void _toggle(_DaySection section) =>
      setState(() => _open = _open == section ? null : section);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final figures = widget.figures;
    final point = figures.dashboard.daily.isEmpty
        ? null
        : figures.dashboard.daily.first;
    final contacts = figures.calls
        .map((call) => call.contactName)
        .toSet()
        .length;
    final missed = figures.missed.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.gutter,
        0,
        widget.gutter,
        widget.gutter,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.l),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.lg,
              boxShadow: AppEffects.card(p),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Iconsax.call,
                      accent: _Accent.blue,
                      value: '${point?.calls ?? 0}',
                      label: 'Calls made',
                    ),
                  ),
                  _VerticalRule(color: p.border),
                  Expanded(
                    child: _StatTile(
                      icon: Iconsax.people,
                      accent: _Accent.purple,
                      value: '$contacts',
                      label: 'Contacts visited',
                    ),
                  ),
                  _VerticalRule(color: p.border),
                  Expanded(
                    child: _StatTile(
                      icon: Iconsax.warning_2,
                      accent: _Accent.red,
                      value: '$missed',
                      label: 'Missed so far this month',
                      alert: missed > 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          _section(
            _DaySection.calls,
            title: 'Calls',
            count: '${figures.calls.length}',
            body: figures.calls.isEmpty
                ? Text(
                    'No calls on this day.',
                    style: text.bodyMedium?.copyWith(color: p.inkMuted),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final call in figures.calls)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.m),
                          child: _DayCallRow(call: call),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpace.m),
          _section(
            _DaySection.missed,
            title: 'Missed calls until this day',
            count: '$missed',
            body: missed == 0
                ? Text(
                    'Every contact in scope was visited.',
                    style: text.bodyMedium?.copyWith(color: p.inkMuted),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final contact in figures.missed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.m),
                          child: _MissedRow(contact: contact),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// An expanded section takes the remaining height and scrolls inside itself; a collapsed one is only its header.
  Widget _section(
    _DaySection section, {
    required String title,
    required String count,
    required Widget body,
  }) {
    final expanded = _open == section;
    final card = _CollapsibleCard(
      title: title,
      count: count,
      expanded: expanded,
      onTap: () => _toggle(section),
      body: body,
    );
    return expanded ? Expanded(child: card) : card;
  }
}

/// A white card with a header that opens and closes its body.
class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTap,
    required this.body,
  });

  final String title;
  final String count;
  final bool expanded;
  final VoidCallback onTap;
  final Widget body;

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
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: AppRadius.sm,
            onTap: onTap,
            child: Row(
              children: [
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
                  count,
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                ),
                const SizedBox(width: AppSpace.s),
                RotatedBox(
                  quarterTurns: expanded ? 1 : 0,
                  child: Icon(
                    Iconsax.arrow_right_3,
                    size: 16,
                    color: p.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpace.l),
            Expanded(child: body),
          ],
        ],
      ),
    );
  }
}

/// One contact that is still unvisited this month: its name, category and zone.
class _MissedRow extends StatelessWidget {
  const _MissedRow({required this.contact});

  final MissedContact contact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _Accent.red.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.call_remove,
              size: 18,
              color: _Accent.red.color,
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.contactName,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${contact.categoryName}  ·  ${contact.zoneName}',
                  style: text.bodySmall?.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.s),
      color: color,
    );
  }
}

/// A tinted icon square beside its value and label, as on the person page.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.alert = false,
  });

  final IconData icon;
  final _Accent accent;
  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.tint,
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, size: 20, color: accent.color),
        ),
        const SizedBox(height: AppSpace.s),
        Text(
          value,
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: alert ? _Accent.red.color : p.ink,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: p.inkMuted),
        ),
      ],
    );
  }
}

/// One call, in the same bordered row as the person page: avatar, name and category, time, products and status.
class _DayCallRow extends StatelessWidget {
  const _DayCallRow({required this.call});

  final TeamCallLine call;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final chemist = call.categoryName.toLowerCase().contains('chemist');
    final accent = chemist ? _Accent.purple : _Accent.blue;
    final status = _statusStyle(call.status);
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.health, size: 22, color: accent.color),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${call.contactName}  ·  ${call.categoryName}',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${call.visitTime.substring(0, 5)}  ·  ${call.repName}  ·  ${call.zoneName}',
                  style: text.bodySmall?.copyWith(color: p.inkMuted),
                ),
                if (call.products.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s),
                  Wrap(
                    spacing: AppSpace.xs,
                    runSpacing: AppSpace.xs,
                    children: [
                      for (final product in call.products)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s,
                            vertical: AppSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            color: p.border.withValues(alpha: 0.5),
                            borderRadius: AppRadius.sm,
                          ),
                          child: Text(
                            product,
                            style: text.labelSmall?.copyWith(color: p.ink),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s,
              vertical: AppSpace.xs,
            ),
            decoration: BoxDecoration(
              color: status.$2,
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              status.$1,
              style: text.labelMedium?.copyWith(
                color: status.$3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The label, background and text colour for a call's status, as on the person page.
  static (String, Color, Color) _statusStyle(String status) => switch (status) {
    'completed' => ('Reported', _Accent.green.tint, _Accent.green.color),
    'disputed' => ('Disputed', _Accent.red.tint, _Accent.red.color),
    _ => ('Open', _Accent.blue.tint, _Accent.blue.color),
  };
}

/// One zone over the dashboard's period: its coverage and figures, then its calls and the contacts still unvisited.
/// The layout follows the day page: calls open first, and only one section is open at a time.
class ZoneDetailView extends StatefulWidget {
  const ZoneDetailView({
    super.key,
    required this.zone,
    required this.from,
    required this.to,
  });

  final ZoneLine zone;
  final DateTime from;
  final DateTime to;

  @override
  State<ZoneDetailView> createState() => _ZoneDetailViewState();
}

class _ZoneDetailViewState extends State<ZoneDetailView> {
  late final Future<_ZoneFigures> _figures = _load();

  Future<_ZoneFigures> _load() async {
    final service = TeamDashboardService(Get.find<ApiService>());
    final calls = await service.fetchCalls(
      from: widget.from,
      to: widget.to,
      zoneId: widget.zone.zoneId,
    );
    final missed = await service.fetchMissed(
      widget.to,
      zoneId: widget.zone.zoneId,
    );
    return _ZoneFigures(calls: calls, missed: missed);
  }

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
          widget.zone.zoneName,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: FutureBuilder<_ZoneFigures>(
            future: _figures,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingList(count: 3);
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return EmptyState(
                  icon: Iconsax.warning_2,
                  title: 'Could not load this zone',
                  message: error is AppException
                      ? error.message
                      : 'Try again in a moment.',
                );
              }
              return _ZoneBody(
                zone: widget.zone,
                from: widget.from,
                to: widget.to,
                figures: snapshot.data!,
                gutter: AppLayout.gutter(size),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ZoneFigures {
  const _ZoneFigures({required this.calls, required this.missed});

  final List<TeamCallLine> calls;
  final List<MissedContact> missed;
}

class _ZoneBody extends StatefulWidget {
  const _ZoneBody({
    required this.zone,
    required this.from,
    required this.to,
    required this.figures,
    required this.gutter,
  });

  final ZoneLine zone;
  final DateTime from;
  final DateTime to;
  final _ZoneFigures figures;
  final double gutter;

  @override
  State<_ZoneBody> createState() => _ZoneBodyState();
}

class _ZoneBodyState extends State<_ZoneBody> {
  _DaySection? _open = _DaySection.calls;

  void _toggle(_DaySection section) =>
      setState(() => _open = _open == section ? null : section);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final zone = widget.zone;
    final fraction = zone.coverageTotal == 0
        ? 0.0
        : zone.contactsVisited / zone.coverageTotal;
    final missed = widget.figures.missed.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.gutter,
        0,
        widget.gutter,
        widget.gutter,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.l),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.lg,
              boxShadow: AppEffects.card(p),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 112,
                          height: 112,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: fraction,
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                  color: _Accent.blue.color,
                                  backgroundColor: p.border,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${zone.contactsVisited} of ${zone.coverageTotal}',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: p.ink,
                                    ),
                                  ),
                                  Text(
                                    '${zone.coveragePercent.toStringAsFixed(1)}%',
                                    style: text.bodySmall?.copyWith(
                                      color: p.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.s),
                        Text(
                          'Contacts covered',
                          style: text.bodySmall?.copyWith(color: p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  _VerticalRule(color: p.border),
                  Expanded(
                    child: Column(
                      children: [
                        _StatTile(
                          icon: Iconsax.call,
                          accent: _Accent.blue,
                          value: '${zone.calls}',
                          label: 'Calls in period',
                        ),
                        const SizedBox(height: AppSpace.l),
                        _StatTile(
                          icon: Iconsax.warning_2,
                          accent: _Accent.red,
                          value: '$missed',
                          label: 'Missed so far this month',
                          alert: missed > 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          _section(
            _DaySection.calls,
            title: 'Calls',
            count: '${widget.figures.calls.length}',
            body: widget.figures.calls.isEmpty
                ? Text(
                    'No calls in this period.',
                    style: text.bodyMedium?.copyWith(color: p.inkMuted),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final call in widget.figures.calls)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.m),
                          child: _DayCallRow(call: call),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpace.m),
          _section(
            _DaySection.missed,
            title: 'Missed contacts',
            count: '$missed',
            body: missed == 0
                ? Text(
                    'Every contact in this zone was visited.',
                    style: text.bodyMedium?.copyWith(color: p.inkMuted),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final contact in widget.figures.missed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.m),
                          child: _MissedRow(contact: contact),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    _DaySection section, {
    required String title,
    required String count,
    required Widget body,
  }) {
    final expanded = _open == section;
    final card = _CollapsibleCard(
      title: title,
      count: count,
      expanded: expanded,
      onTap: () => _toggle(section),
      body: body,
    );
    return expanded ? Expanded(child: card) : card;
  }
}

/// The calls and the missed contacts a stats page lists.
class _StatsData {
  const _StatsData({required this.calls, required this.missed});

  final List<TeamCallLine> calls;
  final List<MissedContact> missed;
}

/// A stats page: this month's figures, then the calls and, when there are any, the missed contacts.
/// Only one section is open at a time.
class _StatsPage extends StatefulWidget {
  const _StatsPage({
    required this.title,
    required this.tiles,
    required this.load,
    required this.emptyCalls,
    required this.emptyMissed,
    this.showMissed = true,
  });

  final String title;
  final List<Widget> tiles;
  final Future<_StatsData> Function() load;
  final String emptyCalls;
  final String emptyMissed;
  final bool showMissed;

  @override
  State<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<_StatsPage> {
  late final Future<_StatsData> _data = widget.load();
  _DaySection? _open = _DaySection.calls;

  void _toggle(_DaySection section) =>
      setState(() => _open = _open == section ? null : section);

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
          widget.title,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: FutureBuilder<_StatsData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingList(count: 3);
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return EmptyState(
                  icon: Iconsax.warning_2,
                  title: 'Could not load these figures',
                  message: error is AppException
                      ? error.message
                      : 'Try again in a moment.',
                );
              }
              final data = snapshot.data!;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.gutter(size),
                  0,
                  AppLayout.gutter(size),
                  AppLayout.gutter(size),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.l),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: AppRadius.lg,
                        boxShadow: AppEffects.card(p),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This month',
                            style: text.bodySmall?.copyWith(color: p.inkMuted),
                          ),
                          const SizedBox(height: AppSpace.m),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < widget.tiles.length;
                                  i++
                                ) ...[
                                  if (i > 0) _VerticalRule(color: p.border),
                                  Expanded(child: widget.tiles[i]),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.l),
                    _section(
                      _DaySection.calls,
                      title: 'Calls',
                      count: '${data.calls.length}',
                      body: data.calls.isEmpty
                          ? Text(
                              widget.emptyCalls,
                              style: text.bodyMedium?.copyWith(
                                color: p.inkMuted,
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (final call in data.calls)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpace.m,
                                    ),
                                    child: _DayCallRow(call: call),
                                  ),
                              ],
                            ),
                    ),
                    if (widget.showMissed) ...[
                      const SizedBox(height: AppSpace.m),
                      _section(
                        _DaySection.missed,
                        title: 'Missed contacts',
                        count: '${data.missed.length}',
                        body: data.missed.isEmpty
                            ? Text(
                                widget.emptyMissed,
                                style: text.bodyMedium?.copyWith(
                                  color: p.inkMuted,
                                ),
                              )
                            : ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  for (final contact in data.missed)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpace.m,
                                      ),
                                      child: _MissedRow(contact: contact),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _section(
    _DaySection section, {
    required String title,
    required String count,
    required Widget body,
  }) {
    final expanded = _open == section;
    final card = _CollapsibleCard(
      title: title,
      count: count,
      expanded: expanded,
      onTap: () => _toggle(section),
      body: body,
    );
    return expanded ? Expanded(child: card) : card;
  }
}

/// One product's stats for this month: its calls, contacts and reps, and every call that gave it.
class ProductStatsView extends StatelessWidget {
  const ProductStatsView({
    super.key,
    required this.productId,
    required this.name,
    required this.stat,
  });

  final int productId;
  final String name;
  final ProductLine? stat;

  @override
  Widget build(BuildContext context) {
    final figures = stat;
    return _StatsPage(
      title: name,
      emptyCalls: 'No calls with this product this month.',
      emptyMissed: '',
      showMissed: false,
      tiles: [
        _StatTile(
          icon: Iconsax.call,
          accent: _Accent.blue,
          value: '${figures?.calls ?? 0}',
          label: 'Calls',
        ),
        _StatTile(
          icon: Iconsax.people,
          accent: _Accent.purple,
          value: '${figures?.contactsVisited ?? 0}',
          label: 'Contacts',
        ),
        _StatTile(
          icon: Iconsax.user,
          accent: _Accent.green,
          value: '${figures?.reps ?? 0}',
          label: 'Reps',
        ),
      ],
      load: () async {
        final today = indiaToday();
        final calls = await TeamDashboardService(Get.find<ApiService>())
            .fetchCalls(
              from: DateTime(today.year, today.month),
              to: today,
              productId: productId,
            );
        return _StatsData(calls: calls, missed: const []);
      },
    );
  }
}

/// One category's stats for this month: its calls and contacts, every call made in it, and the contacts in it not yet visited.
class CategoryStatsView extends StatelessWidget {
  const CategoryStatsView({
    super.key,
    required this.categoryName,
    required this.stat,
  });

  final String categoryName;
  final CategoryLine? stat;

  @override
  Widget build(BuildContext context) {
    final figures = stat;
    return _StatsPage(
      title: categoryName,
      emptyCalls: 'No calls in this category this month.',
      emptyMissed: 'Every contact in this category was visited this month.',
      tiles: [
        _StatTile(
          icon: Iconsax.call,
          accent: _Accent.blue,
          value: '${figures?.calls ?? 0}',
          label: 'Calls',
        ),
        _StatTile(
          icon: Iconsax.people,
          accent: _Accent.purple,
          value: '${figures?.contactsVisited ?? 0}',
          label: 'Contacts',
        ),
      ],
      load: () async {
        final today = indiaToday();
        final from = DateTime(today.year, today.month);
        final service = TeamDashboardService(Get.find<ApiService>());
        final calls = await service.fetchCalls(
          from: from,
          to: today,
          categoryName: categoryName,
        );
        final missed = await service.fetchMissed(
          today,
          categoryName: categoryName,
        );
        return _StatsData(calls: calls, missed: missed);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/business_time.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/member_report.dart';
import '../../services/api_service.dart';
import '../../services/app_exception.dart';
import '../../services/auth_service.dart';
import '../../services/member_report_service.dart';
import '../../services/visit_service.dart';
import '../../models/contact.dart';

/// What the member detail page opens on: the person and the period.
class MemberDetailArgs {
  const MemberDetailArgs({
    required this.userId,
    required this.name,
    required this.from,
    required this.to,
  });

  final int userId;
  final String name;
  final DateTime from;
  final DateTime to;
}

/// One person over the period: their figures, each day they reported, and every call.
class MemberDetailView extends StatefulWidget {
  const MemberDetailView({super.key});

  @override
  State<MemberDetailView> createState() => _MemberDetailViewState();
}

class _MemberDetailViewState extends State<MemberDetailView> {
  late final MemberDetailArgs _args = Get.arguments as MemberDetailArgs;
  late DateTime _from = _args.from;
  late DateTime _to = _args.to;
  late Future<MemberDetail> _detail = _load();

  /// The day picked in the activity strip or the calendar. Kept here so it survives a reload of the period.
  DateTime? _day;

  Future<MemberDetail> _load() =>
      MemberReportService(Get.find<ApiService>())
          .fetchMember(_args.userId, from: _from, to: _to);

  void _reload() {
    setState(() {
      _detail = _load();
    });
  }

  void _selectDay(DateTime? day) => setState(() => _day = day);

  /// Moves the whole page to another period, and selects the day that was picked to get there.
  void _changePeriod(DateTime from, DateTime to, DateTime day) {
    _from = from;
    _to = to;
    _day = day;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _args.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.palette.ink,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: FutureBuilder<MemberDetail>(
            future: _detail,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingList(count: 3);
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return EmptyState(
                  icon: Iconsax.warning_2,
                  title: 'Report unavailable',
                  message: error is AppException
                      ? error.message
                      : 'Could not load this report.',
                );
              }
              return _DetailBody(
                detail: snapshot.data!,
                args: _args,
                from: _from,
                to: _to,
                selectedDay: _day,
                gutter: AppLayout.gutter(size),
                onChanged: _reload,
                onSelectDay: _selectDay,
                onPeriodChanged: _changePeriod,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Colour pairs for the detail page: the blue of calls, the green of reported days, and so on.
class _Accent {
  const _Accent(this.color, this.tint);

  final Color color;
  final Color tint;

  static const blue = _Accent(Color(0xFF1F5FDB), Color(0xFFE6EEFB));
  static const green = _Accent(Color(0xFF1E9E5A), Color(0xFFE2F4EA));
  static const orange = _Accent(Color(0xFFE8871E), Color(0xFFFDEEDC));
  static const red = _Accent(Color(0xFFE5484D), Color(0xFFFBE4E4));
  static const purple = _Accent(Color(0xFF7B5CE0), Color(0xFFEEE9FD));
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One person over the period: the coverage and figures, the last seven days, then every call.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.args,
    required this.from,
    required this.to,
    required this.selectedDay,
    required this.gutter,
    required this.onChanged,
    required this.onSelectDay,
    required this.onPeriodChanged,
  });

  final MemberDetail detail;
  final MemberDetailArgs args;
  final DateTime from;
  final DateTime to;
  final DateTime? selectedDay;
  final double gutter;
  final VoidCallback onChanged;
  final ValueChanged<DateTime?> onSelectDay;
  final void Function(DateTime from, DateTime to, DateTime day) onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final member = detail.member;
    final callsByDay = {
      for (final day in detail.days) DateUtils.dateOnly(day.day): day.calls,
    };
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.xxl),
      children: [
        Text(
          '${formatDay(from)} to ${formatDay(to)}  ·  ${member.roleName}',
          style: text.bodyMedium?.copyWith(color: p.inkMuted),
        ),
        const SizedBox(height: AppSpace.l),
        _OverviewCard(member: member),
        const SizedBox(height: AppSpace.l),
        _ActivityCard(
          cells: _lastSevenDays(callsByDay),
          selectedDay: selectedDay,
          onDayTap: (day) => onSelectDay(selectedDay == day ? null : day),
          onViewCalendar: () => _openCalendar(context),
        ),
        const SizedBox(height: AppSpace.l),
        _CallsCard(
          calls: detail.calls,
          selectedDay: selectedDay,
          onClearDay: () => onSelectDay(null),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// Opens the calendar. A day picked there moves the page to its month and selects that day.
  Future<void> _openCalendar(BuildContext context) async {
    final picked = await Get.bottomSheet<DateTime>(
      _CalendarSheet(
        userId: args.userId,
        service: MemberReportService(Get.find<ApiService>()),
      ),
    );
    if (picked == null) return;
    final today = indiaToday();
    final monthStart = DateTime(picked.year, picked.month);
    final monthEnd = DateTime(picked.year, picked.month + 1, 0);
    onPeriodChanged(
      monthStart,
      monthEnd.isAfter(today) ? today : monthEnd,
      picked,
    );
  }

  /// Seven days. They end on the selected day when there is one, otherwise on the period's last day.
  List<_DayCell> _lastSevenDays(Map<DateTime, int> callsByDay) {
    final end = DateUtils.dateOnly(selectedDay ?? to);
    return [
      for (var offset = 6; offset >= 0; offset--)
        () {
          final day = end.subtract(Duration(days: offset));
          return _DayCell(day: day, calls: callsByDay[day] ?? 0);
        }(),
    ];
  }
}

class _DayCell {
  const _DayCell({required this.day, required this.calls});

  final DateTime day;
  final int calls;
}

/// The coverage ring with the contacts count inside, and the four figures beside it.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.member});

  final MemberRow member;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final coverage = member.coverageTotal == 0
        ? 0.0
        : member.contactsVisited / member.coverageTotal;
    return Container(
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
              flex: 2,
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: coverage,
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
                              '${member.contactsVisited} of ${member.coverageTotal}',
                              style: text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                            ),
                            Text(
                              '${(coverage * 100).toStringAsFixed(1)}%',
                              style: text.bodyMedium?.copyWith(
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
                    style: text.bodyMedium?.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.m),
              color: p.border,
            ),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Iconsax.call,
                            accent: _Accent.blue,
                            value: '${member.calls}',
                            label: 'Calls',
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s,
                          ),
                          color: p.border,
                        ),
                        Expanded(
                          child: _StatTile(
                            icon: Iconsax.calendar_tick,
                            accent: _Accent.green,
                            value: '${member.daysReported}',
                            label: 'Days reported',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: AppSpace.l * 2,
                    thickness: 1,
                    color: p.border,
                  ),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Iconsax.calendar_remove,
                            accent: _Accent.orange,
                            value: '${member.daysLeave}',
                            label: 'Days on leave',
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s,
                          ),
                          color: p.border,
                        ),
                        Expanded(
                          child: _StatTile(
                            icon: Iconsax.warning_2,
                            accent: _Accent.red,
                            value: '${member.daysNeverReported}',
                            label: 'Days never reported',
                            alert: true,
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
      ),
    );
  }
}

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
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.tint,
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, size: 22, color: accent.color),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: alert ? _Accent.red.color : p.ink,
                ),
              ),
              Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recent activity: seven square day tiles in a strip that scrolls sideways. The busiest day is selected.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.cells,
    required this.selectedDay,
    required this.onDayTap,
    required this.onViewCalendar,
  });

  final List<_DayCell> cells;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onViewCalendar;

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
              Expanded(
                child: Text(
                  'Recent activity',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewCalendar,
                child: Row(
                  children: [
                    Text(
                      'View calendar',
                      style: text.bodyMedium?.copyWith(
                        color: _Accent.blue.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 16,
                      color: _Accent.blue.color,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.s),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: _DayTile(
                      cell: cells[i],
                      selected: cells[i].day == selectedDay,
                      onTap: () => onDayTap(cells[i].day),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.cell,
    required this.selected,
    required this.onTap,
  });

  final _DayCell cell;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final hasCalls = cell.calls > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
        decoration: BoxDecoration(
          color: selected ? _Accent.blue.tint : p.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: selected ? _Accent.blue.color : p.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${cell.day.day}',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            Text(
              _monthNames[cell.day.month - 1],
              style: text.bodySmall?.copyWith(
                color: hasCalls ? _Accent.blue.color : p.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            if (hasCalls)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cell.calls.clamp(0, 3); i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _Accent.blue.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              )
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: p.inkMuted,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(height: AppSpace.xs),
            Text(
              hasCalls
                  ? '${cell.calls} ${cell.calls == 1 ? 'call' : 'calls'}'
                  : 'No calls',
              style: text.bodySmall?.copyWith(
                color: selected
                    ? _Accent.blue.color
                    : (hasCalls ? p.ink : p.inkMuted),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The calendar of the period: each month as a grid, with the calls made on each day.
/// The calendar: one month at a time, back up to a year. Each month's call counts come from the server.
class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet({required this.userId, required this.service});

  final int userId;
  final MemberReportService service;

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  static const _monthsBack = 12;

  final DateTime _today = indiaToday();
  late DateTime _month = DateTime(_today.year, _today.month);
  final Map<DateTime, Map<DateTime, int>> _cache = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _canGoBack =>
      _month.isAfter(DateTime(_today.year, _today.month - _monthsBack));

  bool get _canGoForward =>
      _month.isBefore(DateTime(_today.year, _today.month));

  Future<void> _load() async {
    final month = _month;
    if (_cache.containsKey(month)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    try {
      final detail = await widget.service.fetchMember(
        widget.userId,
        from: month,
        to: monthEnd.isAfter(_today) ? _today : monthEnd,
      );
      if (!mounted) return;
      if (month == _month) {
        _cache[month] = {
          for (final day in detail.days) DateUtils.dateOnly(day.day): day.calls,
        };
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _move(int by) {
    setState(() => _month = DateTime(_month.year, _month.month + by));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: _canGoBack ? () => _move(-1) : null,
                    icon: const Icon(Iconsax.arrow_left_2),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: _canGoForward ? () => _move(1) : null,
                    icon: const Icon(Iconsax.arrow_right_2),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s),
              if (_loading)
                const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                )
              else
                _MonthGrid(
                  month: _month,
                  callsByDay: _cache[_month] ?? const {},
                  today: _today,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One month, Monday first. Days with calls show their count; days after today cannot be picked.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.callsByDay,
    required this.today,
  });

  final DateTime month;
  final Map<DateTime, int> callsByDay;
  final DateTime today;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final rows = ((offset + daysInMonth) / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: text.bodySmall?.copyWith(color: p.inkMuted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _cell(
                    context,
                    row * 7 + column - offset + 1,
                    daysInMonth,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final date = DateTime(month.year, month.month, dayNumber);
    final selectable = !date.isAfter(today);
    final calls = callsByDay[date] ?? 0;
    return GestureDetector(
      onTap: selectable ? () => Navigator.of(context).pop(date) : null,
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: calls > 0 ? _Accent.blue.tint : null,
          borderRadius: AppRadius.sm,
          border: Border.all(
            color: calls > 0
                ? _Accent.blue.color.withValues(alpha: 0.3)
                : p.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selectable ? p.ink : p.inkMuted,
              ),
            ),
            if (calls > 0)
              Text(
                '$calls',
                style: text.labelSmall?.copyWith(
                  color: _Accent.blue.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which calls the list shows: every call, or the calls with one status.
enum _CallFilter {
  all('All calls'),
  reported('Reported'),
  disputed('Disputed'),
  open('Open');

  const _CallFilter(this.label);

  final String label;

  bool matches(String status) => switch (this) {
    _CallFilter.all => true,
    _CallFilter.reported => status == 'completed',
    _CallFilter.disputed => status == 'disputed',
    _CallFilter.open => status != 'completed' && status != 'disputed',
  };
}

/// Every call in the period. The filter narrows it by status; the sort icon flips newest and oldest first.
class _CallsCard extends StatefulWidget {
  const _CallsCard({
    required this.calls,
    required this.selectedDay,
    required this.onClearDay,
    required this.onChanged,
  });

  final List<CallLine> calls;
  final DateTime? selectedDay;
  final VoidCallback onClearDay;
  final VoidCallback onChanged;

  @override
  State<_CallsCard> createState() => _CallsCardState();
}

class _CallsCardState extends State<_CallsCard> {
  _CallFilter _filter = _CallFilter.all;
  bool _newestFirst = true;

  Future<void> _pickFilter() async {
    final choice = await AppDialogs.choose<_CallFilter>(
      title: 'Show calls',
      choices: [
        for (final filter in _CallFilter.values)
          AppChoice<_CallFilter>(
            value: filter,
            label: filter.label,
            icon: Iconsax.filter,
          ),
      ],
    );
    if (choice != null) setState(() => _filter = choice);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final day = widget.selectedDay;
    final onDay = day == null
        ? widget.calls
        : widget.calls
              .where((call) => DateUtils.dateOnly(call.visitDate) == day)
              .toList();
    final shown = onDay.where((call) => _filter.matches(call.status)).toList()
      ..sort((a, b) {
        final byDate = a.visitDate.compareTo(b.visitDate);
        final order = byDate != 0 ? byDate : a.visitTime.compareTo(b.visitTime);
        return _newestFirst ? -order : order;
      });
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
              Expanded(
                child: Text(
                  'Calls',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              ),
              InkWell(
                onTap: _pickFilter,
                child: Row(
                  children: [
                    Text(
                      _filter.label,
                      style: text.bodyMedium?.copyWith(
                        color: _Accent.blue.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Icon(
                      Iconsax.arrow_down_1,
                      size: 16,
                      color: _Accent.blue.color,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.m),
                color: p.border,
              ),
              InkWell(
                onTap: () => setState(() => _newestFirst = !_newestFirst),
                child: Icon(Iconsax.sort, size: 20, color: _Accent.blue.color),
              ),
            ],
          ),
          if (day != null) ...[
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Calls on ${formatDay(day)}',
                    style: text.bodyMedium?.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onClearDay,
                  child: const Text('Show all'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.l),
          if (widget.calls.isEmpty)
            Text(
              'No calls in this period.',
              style: text.bodyMedium?.copyWith(color: p.inkMuted),
            )
          else if (shown.isEmpty)
            Text(
              day == null
                  ? 'No calls match this filter.'
                  : 'No calls on this day match this filter.',
              style: text.bodyMedium?.copyWith(color: p.inkMuted),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.m),
              _CallRow(call: shown[i], onChanged: widget.onChanged),
            ],
        ],
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.call, required this.onChanged});

  final CallLine call;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final chemist = call.categoryName.toLowerCase().contains('chemist');
    final accent = chemist ? _Accent.purple : _Accent.blue;
    final status = _statusStyle(call.status);
    return GestureDetector(
      onTap: () async {
        // Permissions can change while the app is open; reload them so the sheet shows what the user may do now.
        await Get.find<AuthService>().refreshCurrentUser().catchError((_) {});
        final changed = await Get.bottomSheet<bool>(
          _CallDetailSheet(call: call),
        );
        if (changed == true) onChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          borderRadius: AppRadius.md,
          border: Border.all(color: p.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.health, size: 24, color: accent.color),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${call.contactName}  ·  ${contactKind(call.categoryName, call.typeName)}',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${formatDay(call.visitDate)}  ·  ${call.visitTime.substring(0, 5)}',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                const SizedBox(height: AppSpace.s),
                Icon(Iconsax.arrow_right_3, size: 16, color: p.inkMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The label, background and text colour for a call's status.
  static (String, Color, Color) _statusStyle(String status) => switch (status) {
    'completed' => ('Reported', _Accent.green.tint, _Accent.green.color),
    'disputed' => ('Disputed', _Accent.red.tint, _Accent.red.color),
    _ => ('Open', _Accent.blue.tint, _Accent.blue.color),
  };
}

/// One call in full: the contact, when, the status, the products and the remarks the rep wrote.
class _CallDetailSheet extends StatelessWidget {
  const _CallDetailSheet({required this.call});

  final CallLine call;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final status = _CallRow._statusStyle(call.status);
    final remarks = call.remarks.trim();
    final canSettle =
        call.status == 'disputed' &&
        Get.find<AuthService>().can('visits.review');
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      call.contactName,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                  ),
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
              const SizedBox(height: AppSpace.xs),
              Text(
                contactKind(call.categoryName, call.typeName),
                style: text.bodyMedium?.copyWith(color: p.inkMuted),
              ),
              const SizedBox(height: AppSpace.l),
              _DetailLine(label: 'Date', value: formatDay(call.visitDate)),
              _DetailLine(label: 'Time', value: call.visitTime.substring(0, 5)),
              _DetailLine(
                label: 'Products',
                value: call.products.isEmpty
                    ? 'None recorded'
                    : call.products.join(', '),
              ),
              _DetailLine(
                label: 'Remarks',
                value: remarks.isEmpty ? 'No remarks' : remarks,
              ),
              if (canSettle) ...[
                const SizedBox(height: AppSpace.s),
                Text(
                  'The partner disputed this call. Who should be credited?',
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                _SettleButton(
                  label: 'Grant both',
                  decision: 'both',
                  call: call,
                  filled: true,
                ),
                const SizedBox(height: AppSpace.s),
                _SettleButton(
                  label: 'Grant them',
                  decision: 'them',
                  call: call,
                ),
                const SizedBox(height: AppSpace.s),
                _SettleButton(
                  label: 'Grant none',
                  decision: 'none',
                  call: call,
                  destructive: true,
                ),
              ],
              const SizedBox(height: AppSpace.m),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One way of settling a disputed call. Closes the sheet with a true result when the server has settled it.
class _SettleButton extends StatelessWidget {
  const _SettleButton({
    required this.label,
    required this.decision,
    required this.call,
    this.filled = false,
    this.destructive = false,
  });

  final String label;
  final String decision;
  final CallLine call;
  final bool filled;
  final bool destructive;

  Future<void> _settle(BuildContext context) async {
    try {
      await VisitService(Get.find<ApiService>())
          .resolveDispute(call.visitId, decision);
      if (context.mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      await AppDialogs.error('Could not settle this call', e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(onPressed: () => _settle(context), child: Text(label))
          : OutlinedButton(
              onPressed: () => _settle(context),
              style: destructive
                  ? OutlinedButton.styleFrom(foregroundColor: _Accent.red.color)
                  : null,
              child: Text(label),
            ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: p.inkMuted)),
          const SizedBox(height: AppSpace.xs),
          Text(value, style: text.bodyMedium?.copyWith(color: p.ink)),
        ],
      ),
    );
  }
}

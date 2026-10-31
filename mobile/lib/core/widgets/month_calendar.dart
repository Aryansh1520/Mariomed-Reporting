import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_tokens.dart';

/// A month calendar styled as Project Y's follow-up calendar: Monday first, a left-aligned title, today ringed,
/// the selected day filled, up to three dots under a day, and a legend below. Days outside
/// [firstDate] to [lastDate] cannot be selected.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    this.markers = const {},
    this.legend = const [],
  });

  final DateTime selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;

  /// Dot colours per day, at most three are shown. Keys are dates with the time left out.
  final Map<DateTime, List<Color>> markers;

  /// What each colour means, shown under the grid.
  final List<(String, Color)> legend;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _focused = widget.selected;

  @override
  void didUpdateWidget(covariant MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _focused = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar<Color>(
            firstDay: widget.firstDate,
            lastDay: widget.lastDate,
            focusedDay: _focused,
            selectedDayPredicate: (day) => isSameDay(widget.selected, day),
            eventLoader: (day) =>
                widget.markers[DateTime(day.year, day.month, day.day)] ??
                const [],
            onDaySelected: (selected, focused) {
              setState(() => _focused = focused);
              widget.onSelected(
                DateTime(selected.year, selected.month, selected.day),
              );
            },
            onPageChanged: (focused) => setState(() => _focused = focused),
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            rowHeight: 36,
            daysOfWeekHeight: 22,
            headerStyle: HeaderStyle(
              titleCentered: false,
              formatButtonVisible: false,
              headerPadding: const EdgeInsets.only(bottom: AppSpace.s),
              titleTextStyle:
                  text.titleMedium?.copyWith(fontWeight: FontWeight.w800) ??
                  const TextStyle(fontWeight: FontWeight.w800),
              leftChevronIcon: Icon(
                Iconsax.arrow_left_2,
                size: 18,
                color: p.ink,
              ),
              rightChevronIcon: Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: p.ink,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  text.labelSmall?.copyWith(
                    color: p.inkMuted,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(),
              weekendStyle:
                  text.labelSmall?.copyWith(
                    color: p.inkMuted,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: const EdgeInsets.all(3),
              defaultTextStyle: text.bodyMedium ?? const TextStyle(),
              weekendTextStyle: text.bodyMedium ?? const TextStyle(),
              disabledTextStyle: (text.bodyMedium ?? const TextStyle())
                  .copyWith(color: p.inkMuted.withValues(alpha: 0.4)),
              todayTextStyle:
                  text.bodyMedium?.copyWith(
                    color: p.primary,
                    fontWeight: FontWeight.w800,
                  ) ??
                  const TextStyle(),
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.primary, width: 1.5),
              ),
              selectedTextStyle:
                  text.bodyMedium?.copyWith(
                    color: p.onPrimary,
                    fontWeight: FontWeight.w800,
                  ) ??
                  const TextStyle(),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.primary,
              ),
            ),
            calendarBuilders: CalendarBuilders<Color>(
              markerBuilder: (context, day, colours) {
                if (colours.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final colour in colours.take(3))
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: colour,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.legend.isNotEmpty) ...[
            const SizedBox(height: AppSpace.m),
            _Legend(items: widget.legend),
          ],
        ],
      ),
    );
  }
}

/// The colour key under the grid: a dot and its meaning per item.
class _Legend extends StatelessWidget {
  const _Legend({required this.items});

  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpace.m,
      runSpacing: AppSpace.xs,
      children: [
        for (final (label, colour) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(label, style: text.labelSmall?.copyWith(color: p.inkMuted)),
            ],
          ),
      ],
    );
  }
}

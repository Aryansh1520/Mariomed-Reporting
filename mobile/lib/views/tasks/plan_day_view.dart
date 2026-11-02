import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/plan_day_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/business_time.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/month_calendar.dart';
import '../../models/contact.dart';
import '../../models/plan.dart';

/// The Plan Day tab. The calendar is on top; the selected day is either marked as leave, or holds the calls planned for it.
/// Plans are personal goals. Each planned call becomes achieved when the rep visits that contact on that day.
class PlanDayView extends GetView<PlanDayController> {
  const PlanDayView({super.key});

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
          child: Obx(
            () => MonthCalendar(
              selected: controller.selectedDate.value,
              firstDate: controller.firstDate,
              lastDate: controller.lastDate,
              markers: _markers(context),
              legend: [
                ('Planned', context.palette.info),
                ('Open', context.palette.warning),
                ('Achieved', context.palette.go),
                ('Missed', context.palette.alert),
                ('Leave', context.palette.accent),
              ],
              onSelected: controller.selectDate,
            ),
          ),
        ),
        Expanded(child: Obx(() => _dayBody(context))),
      ],
    );
  }

  Map<DateTime, List<Color>> _markers(BuildContext context) {
    final p = context.palette;
    final markers = <DateTime, List<Color>>{};
    for (final day in controller.days) {
      final key = DateTime(
        day.planDate.year,
        day.planDate.month,
        day.planDate.day,
      );
      markers[key] = day.isLeave
          ? [p.accent]
          : [for (final item in day.items) _colourOf(p, item.status)];
    }
    for (
      var date = controller.firstDate;
      !date.isAfter(controller.lastDate);
      date = date.add(const Duration(days: 1))
    ) {
      if (isSunday(date)) markers[date] = [p.accent];
    }
    return markers;
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
    final date = controller.selectedDate.value;
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
          _DayHeader(date: date, controller: controller),
          const SizedBox(height: AppSpace.xl),
          if (!controller.isLeave(date) && !isSunday(date))
            _PlannedCalls(date: date, controller: controller),
        ],
      ),
    );
  }

  static Color _colourOf(AppPalette p, String status) => switch (status) {
    'achieved' => p.go,
    'open' => p.warning,
    'missed' => p.alert,
    _ => p.info,
  };
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.controller});

  final DateTime date;
  final PlanDayController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final leave = controller.isLeave(date);
    final planned = controller.itemsOn(date).length;
    final summary = isSunday(date)
        ? 'Sunday is a leave day for everyone.'
        : leave
        ? 'Marked as leave. No calls can be reported on this day.'
        : planned == 0
        ? 'Nothing planned yet.'
        : '$planned planned ${planned == 1 ? 'call' : 'calls'}.';
    final sunday = isSunday(date);
    final blocked = !leave && planned > 0;
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
                blocked
                    ? 'Remove the planned calls first to mark this day as leave.'
                    : summary,
                style: text.bodySmall?.copyWith(color: p.inkMuted),
              ),
            ],
          ),
        ),
        if (!sunday) ...[
          const SizedBox(width: AppSpace.m),
          Obx(
            () => OutlinedButton(
              onPressed: controller.isBusy.value || blocked
                  ? null
                  : () => _toggle(context, !leave),
              child: Text(leave ? 'Remove leave' : 'Mark as leave'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggle(BuildContext context, bool on) async {
    final problem = await controller.setLeave(date, on: on);
    if (problem != null && context.mounted)
      await AppDialogs.error('Could not change the leave', problem);
  }
}

/// The second option, when the day is not leave: the calls planned for it, and a way to add more.
class _PlannedCalls extends StatelessWidget {
  const _PlannedCalls({required this.date, required this.controller});

  final DateTime date;
  final PlanDayController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final items = controller.itemsOn(date);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Planned calls',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : () => _pickContact(context),
                icon: const Icon(Iconsax.add, size: 18),
                label: const Text('Add call'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          if (items.isEmpty)
            Text(
              'Pick the contacts you want to reach on this day.',
              style: text.bodyMedium?.copyWith(color: p.inkMuted),
            )
          else
            _PlanPanel(items: items, controller: controller),
        ],
      );
    });
  }

  Future<void> _pickContact(BuildContext context) async {
    final chosen = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactPicker(date: date, controller: controller),
    );
    if (chosen == null || chosen.isEmpty) return;
    final problem = await controller.addItems(date, chosen);
    if (problem != null && context.mounted) {
      await AppDialogs.error('Could not plan every call', problem);
    }
  }
}

/// Planned calls in one hairline-separated panel, each with its status and a way to remove it.
class _PlanPanel extends StatelessWidget {
  const _PlanPanel({required this.items, required this.controller});

  final List<PlanItem> items;
  final PlanDayController controller;

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
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.border),
              _PlanRow(item: items[i], controller: controller, text: text),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.item,
    required this.controller,
    required this.text,
  });

  final PlanItem item;
  final PlanDayController controller;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (label, colour) = _statusOf(p, item.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.m,
        AppSpace.s,
        AppSpace.m,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.contactName,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${contactKind(item.categoryName, item.typeName)}  ·  ${item.zoneName}  ›  ${item.subzoneName}',
                  style: text.bodySmall?.copyWith(color: p.inkMuted),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: colour,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove planned call',
            visualDensity: VisualDensity.compact,
            onPressed: controller.isBusy.value ? null : () => _remove(context),
            icon: Icon(Iconsax.trash, size: 18, color: p.alert),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusOf(AppPalette p, String status) => switch (status) {
    'achieved' => ('Achieved', p.go),
    'open' => ('Open', p.warning),
    'missed' => ('Missed', p.alert),
    _ => ('Planned', p.info),
  };

  Future<void> _remove(BuildContext context) async {
    final problem = await controller.removeItem(item);
    if (problem != null && context.mounted)
      await AppDialogs.error('Could not remove', problem);
  }
}

/// Lists the contacts the rep can plan for. Search narrows the list; each tap ticks a contact, and the
/// button at the bottom plans every ticked contact at once.
class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.date, required this.controller});

  final DateTime date;
  final PlanDayController controller;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  late final Future<List<Contact>> _contacts = widget.controller
      .pickableContacts(widget.date);
  final _search = TextEditingController();
  final _chosen = <int>{};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Contact contact) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      contact.name,
      contactKind(contact.categoryName, contact.typeName),
      contact.zoneName,
      contact.subzoneName,
    ].any((field) => field.toLowerCase().contains(needle));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: FutureBuilder<List<Contact>>(
          future: _contacts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load contacts.', style: text.bodyMedium),
              );
            }
            final all = snapshot.data ?? const <Contact>[];
            if (all.isEmpty) {
              return Center(
                child: Text(
                  'Every contact is already planned for this day.',
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                ),
              );
            }
            final shown = all.where(_matches).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.l,
                    0,
                    AppSpace.l,
                    AppSpace.m,
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search name, category or area',
                      prefixIcon: const Icon(Iconsax.search_normal),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                              icon: const Icon(Iconsax.close_circle),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text(
                            'No contact matches “$_query”.',
                            style: text.bodyMedium?.copyWith(color: p.inkMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: shown.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: p.border),
                          itemBuilder: (context, index) =>
                              _pickerRow(context, shown[index]),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.l,
                    AppSpace.m,
                    AppSpace.l,
                    AppSpace.l,
                  ),
                  child: FilledButton(
                    onPressed: _chosen.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_chosen.toList()),
                    child: Text(
                      _chosen.isEmpty
                          ? 'Select contacts'
                          : 'Plan ${_chosen.length} ${_chosen.length == 1 ? 'call' : 'calls'}',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pickerRow(BuildContext context, Contact contact) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final ticked = _chosen.contains(contact.id);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: ticked,
      activeColor: p.primary,
      title: Text(
        contact.name,
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${contactKind(contact.categoryName, contact.typeName)}  ·  ${contact.zoneName}  ›  ${contact.subzoneName}',
        style: text.bodySmall?.copyWith(color: p.inkMuted),
      ),
      onChanged: (value) => setState(() {
        if (value == true) {
          _chosen.add(contact.id);
        } else {
          _chosen.remove(contact.id);
        }
      }),
    );
  }
}

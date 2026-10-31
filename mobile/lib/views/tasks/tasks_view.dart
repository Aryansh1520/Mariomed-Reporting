import 'package:flutter/material.dart';

import '../../core/widgets/pill_tabs.dart';
import '../../core/theme/app_tokens.dart';
import 'complete_day_view.dart';
import 'plan_day_view.dart';

enum _TasksTab { planDay, completeDay }

/// The Tasks tab: Plan Day for the coming weeks, and Complete Day for closing the days already worked.
/// Text tabs under the title switch between them; the chosen one sits in an outlined pill.
class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  _TasksTab _tab = _TasksTab.planDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.l,
              AppSpace.s,
              AppSpace.l,
              AppSpace.m,
            ),
            child: PillTabs<_TasksTab>(
              items: const [
                (_TasksTab.planDay, 'Plan Day'),
                (_TasksTab.completeDay, 'Complete Day'),
              ],
              selected: _tab,
              onSelected: (value) => setState(() => _tab = value),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab.index,
              children: const [PlanDayView(), CompleteDayView()],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/utils/business_time.dart';
import '../models/team_dashboard.dart';
import '../services/app_exception.dart';
import '../services/team_dashboard_service.dart';

/// The periods the team figures can cover. Custom takes any range the user picks, up to a year.
enum TeamPeriod { today, thisMonth, last7Days, custom }

/// The team-wide dashboard for the chosen period, ending today unless a custom range says otherwise.
class TeamDashboardController extends GetxController {
  TeamDashboardController(this._service);

  final TeamDashboardService _service;

  final period = TeamPeriod.thisMonth.obs;
  final from = Rx<DateTime>(DateTime(indiaToday().year, indiaToday().month));
  final to = Rx<DateTime>(indiaToday());
  final dashboard = Rxn<TeamDashboard>();
  final isLoading = true.obs;
  final loadError = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void choose(TeamPeriod value) {
    final today = indiaToday();
    period.value = value;
    switch (value) {
      case TeamPeriod.today:
        from.value = today;
      case TeamPeriod.thisMonth:
        from.value = DateTime(today.year, today.month);
      case TeamPeriod.last7Days:
        from.value = today.subtract(const Duration(days: 6));
      case TeamPeriod.custom:
        return;
    }
    to.value = today;
    load();
  }

  void setCustomRange(DateTimeRange range) {
    period.value = TeamPeriod.custom;
    from.value = range.start;
    to.value = range.end;
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      dashboard.value = await _service.fetch(from: from.value, to: to.value);
    } on AppException catch (e) {
      loadError.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }
}

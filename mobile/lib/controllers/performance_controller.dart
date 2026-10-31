import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/utils/business_time.dart';
import '../models/member_report.dart';
import '../services/app_exception.dart';
import '../services/member_report_service.dart';

/// The periods a team report can cover. Custom takes any range the user picks, up to a year.
enum PerformancePeriod { thisMonth, lastMonth, last30Days, custom }

/// The team performance table for the chosen period, and the CSV it exports.
class PerformanceController extends GetxController {
  PerformanceController(this._service);

  final MemberReportService _service;

  final period = PerformancePeriod.thisMonth.obs;
  final from = Rx<DateTime>(_monthStart(indiaToday()));
  final to = Rx<DateTime>(indiaToday());
  final members = <MemberRow>[].obs;
  final isLoading = true.obs;
  final loadError = RxnString();

  static DateTime _monthStart(DateTime day) => DateTime(day.year, day.month);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void choose(PerformancePeriod value) {
    final today = indiaToday();
    period.value = value;
    switch (value) {
      case PerformancePeriod.thisMonth:
        from.value = _monthStart(today);
        to.value = today;
      case PerformancePeriod.lastMonth:
        final lastMonthEnd = _monthStart(today)
            .subtract(const Duration(days: 1));
        from.value = _monthStart(lastMonthEnd);
        to.value = lastMonthEnd;
      case PerformancePeriod.last30Days:
        from.value = today.subtract(const Duration(days: 29));
        to.value = today;
      case PerformancePeriod.custom:
        break;
    }
    load();
  }

  void setCustomRange(DateTimeRange range) {
    period.value = PerformancePeriod.custom;
    from.value = range.start;
    to.value = range.end;
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      members.assignAll(
        await _service.fetchMembers(from: from.value, to: to.value),
      );
    } on AppException catch (e) {
      loadError.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// The table as CSV, one row per person, in the order shown on screen.
  String toCsv() {
    final buffer = StringBuffer(
      'Name,Role,Active,Calls,Contacts visited,Contacts in area,Days reported,Days on leave,Days never reported,Plans due,Plans achieved\n',
    );
    for (final row in members) {
      buffer.writeln(
        [
          _csv(row.fullName),
          _csv(row.roleName),
          row.isActive ? 'Yes' : 'No',
          row.calls,
          row.contactsVisited,
          row.coverageTotal,
          row.daysReported,
          row.daysLeave,
          row.daysNeverReported,
          row.plansDue,
          row.plansAchieved,
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static String _csv(String value) => value.contains(',') || value.contains('"')
      ? '"${value.replaceAll('"', '""')}"'
      : value;
}

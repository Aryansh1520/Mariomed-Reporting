import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/business_time.dart';
import '../models/visit.dart';
import '../services/app_exception.dart';
import '../services/plan_service.dart';
import '../services/visit_service.dart';

/// Where a day stands for the rep. Only days inside the grace period are shown, so these are the states that matter.
enum DayStatus { completed, open, today, notReported, missed, leave }

/// Closes the days inside the grace period: the calls on each day, the day's end, and joint calls waiting for an answer.
class CompleteDayController extends GetxController {
  CompleteDayController(this._visits, this._plans);

  final VisitService _visits;
  final PlanService _plans;

  final days = <VisitDay>[].obs;
  final visits = <VisitRecord>[].obs;
  final jointRequests = <JointRequest>[].obs;
  final selectedDate = Rx<DateTime>(_today());
  final isLoading = true.obs;
  final isBusy = false.obs;
  final loadError = RxnString();

  /// The oldest day that can still be closed. Days older than this are read-only.
  DateTime get reportWindowStart =>
      _today().subtract(const Duration(days: AppConstants.visitGraceDays));

  /// The calendar's history. Days before the report window are shown read-only.
  DateTime get firstDate =>
      _today().subtract(const Duration(days: AppConstants.historyDays));

  DateTime get lastDate => _today();

  /// Whether calls on this date can still be changed: today and the grace days before it.
  bool isOpenForReporting(DateTime date) =>
      !date.isBefore(reportWindowStart) && !date.isAfter(lastDate);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      days.assignAll(
        await _visits.listDays(from: firstDate, to: lastDate, mineOnly: true),
      );
      visits.assignAll(
        await _visits.listVisits(from: firstDate, to: lastDate, mineOnly: true),
      );
      jointRequests.assignAll(await _visits.listJointRequests());
    } on AppException catch (e) {
      loadError.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void selectDate(DateTime value) =>
      selectedDate.value = DateUtils.dateOnly(value);

  DayStatus statusOn(DateTime date) {
    if (isSunday(date)) return DayStatus.leave;
    final day = _dayOn(date);
    if (day != null && day.isLeave) return DayStatus.leave;
    if (day != null) return day.isEnded ? DayStatus.completed : DayStatus.open;
    if (_sameDay(date, _today())) return DayStatus.today;
    return isOpenForReporting(date) ? DayStatus.notReported : DayStatus.missed;
  }

  /// A day can be ended until it is ended; the server decides whether the date is still in the grace period.
  bool canEndOn(DateTime date) =>
      isOpenForReporting(date) &&
      statusOn(date) != DayStatus.completed &&
      statusOn(date) != DayStatus.leave;

  /// Sunday is leave for everyone, so it cannot be released.
  bool canReleaseLeaveOn(DateTime date) =>
      !isSunday(date) && _dayOn(date)?.isLeave == true;

  List<VisitRecord> visitsOn(DateTime date) => [
    for (final visit in visits)
      if (_sameDay(visit.visitDate, date)) visit,
  ];

  /// The day's last date for reporting, shown to the rep when the day is not reported yet.
  DateTime reportBy(DateTime date) =>
      date.add(const Duration(days: AppConstants.visitGraceDays));

  Future<String?> endDay(DateTime date) => _run(() => _visits.endDay(date));

  /// Releases a leave day, so the rep can report calls on it again.
  Future<String?> removeLeave(DateTime date) =>
      _run(() => _plans.clearLeave(date));

  Future<String?> deleteVisit(VisitRecord visit) =>
      _run(() => _visits.deleteVisit(visit.id));

  Future<String?> answerJoint(JointRequest request, {required bool accept}) =>
      _run(
        () => accept
            ? _visits.acceptJoint(request.visitId)
            : _visits.disputeJoint(request.visitId),
      );

  /// Runs a change, then reloads. Returns the error to show, or null when it worked.
  Future<String?> _run(Future<void> Function() change) async {
    isBusy.value = true;
    try {
      await change();
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    } finally {
      isBusy.value = false;
    }
  }

  VisitDay? _dayOn(DateTime date) {
    for (final day in days) {
      if (_sameDay(day.visitDate, date)) return day;
    }
    return null;
  }

  static DateTime _today() => indiaToday();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

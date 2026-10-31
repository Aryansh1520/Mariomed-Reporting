import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/business_time.dart';
import '../models/contact.dart';
import '../models/plan.dart';
import '../services/app_exception.dart';
import '../services/contact_service.dart';
import '../services/plan_service.dart';

/// The rep's plans for the coming month: each day is either leave, or a list of calls planned for it.
/// Plans are personal; nobody else reads them.
class PlanDayController extends GetxController {
  PlanDayController(this._plans, this._contacts);

  final PlanService _plans;
  final ContactService _contacts;

  final days = <PlanDay>[].obs;
  final selectedDate = Rx<DateTime>(_today());
  final isLoading = true.obs;
  final isBusy = false.obs;
  final loadError = RxnString();

  DateTime get firstDate => _today();

  DateTime get lastDate =>
      _today().add(const Duration(days: AppConstants.planHorizonDays));

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      days.assignAll(await _plans.listPlans(from: firstDate, to: lastDate));
    } on AppException catch (e) {
      loadError.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void selectDate(DateTime value) =>
      selectedDate.value = DateTime(value.year, value.month, value.day);

  PlanDay? dayOn(DateTime date) {
    for (final day in days) {
      if (_sameDay(day.planDate, date)) return day;
    }
    return null;
  }

  bool isLeave(DateTime date) => dayOn(date)?.isLeave ?? false;

  List<PlanItem> itemsOn(DateTime date) => dayOn(date)?.items ?? const [];

  Future<String?> setLeave(DateTime date, {required bool on}) =>
      _run(() => on ? _plans.setLeave(date) : _plans.clearLeave(date));

  /// Plans each contact in turn. The first failure stops the run and is returned; the ones before it stay planned.
  Future<String?> addItems(DateTime date, List<int> contactIds) =>
      _run(() async {
        for (final contactId in contactIds) {
          await _plans.addItem(date, contactId);
        }
      });

  Future<String?> removeItem(PlanItem item) =>
      _run(() => _plans.removeItem(item.id));

  /// Every active contact the rep can see, minus the ones already planned for the date.
  Future<List<Contact>> pickableContacts(DateTime date) async {
    final planned = {for (final item in itemsOn(date)) item.contactId};
    final collected = <Contact>[];
    var page = 1;
    while (true) {
      final result = await _contacts.listContacts(page: page);
      collected.addAll(result.items);
      if (result.items.isEmpty || collected.length >= result.total) break;
      page++;
    }
    return [
      for (final contact in collected)
        if (contact.isActive && !planned.contains(contact.id)) contact,
    ];
  }

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

  static DateTime _today() => indiaToday();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

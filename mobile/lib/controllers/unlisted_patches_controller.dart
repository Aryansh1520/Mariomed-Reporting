import 'package:get/get.dart';

import '../core/utils/business_time.dart';
import '../models/unlisted.dart';
import '../services/app_exception.dart';
import '../services/unlisted_service.dart';

/// The unlisted doctors and chemists of every patch for a period. Defaults to the month so far, like the team dashboard.
class UnlistedPatchesController extends GetxController {
  UnlistedPatchesController(this._service);

  final UnlistedService _service;

  final from = Rx<DateTime>(_monthStart());
  final to = Rx<DateTime>(indiaToday());
  final _patches = <UnlistedPatch>[].obs;
  final _isLoading = true.obs;
  final _errorMessage = RxnString();

  List<UnlistedPatch> get patches => _patches;

  bool get isLoading => _isLoading.value;

  String? get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> setPeriod(DateTime start, DateTime end) async {
    from.value = start;
    to.value = end;
    await load();
  }

  Future<void> load() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      _patches.assignAll(
        await _service.patchStats(from: from.value, to: to.value),
      );
    } on AppException catch (e) {
      _errorMessage.value = e.message;
    } finally {
      _isLoading.value = false;
    }
  }

  static DateTime _monthStart() {
    final today = indiaToday();
    return DateTime(today.year, today.month);
  }
}

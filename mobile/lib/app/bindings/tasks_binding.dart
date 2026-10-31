import 'package:get/get.dart';

import '../../controllers/complete_day_controller.dart';
import '../../controllers/plan_day_controller.dart';
import '../../services/api_service.dart';
import '../../services/contact_service.dart';
import '../../services/plan_service.dart';
import '../../services/visit_service.dart';

/// The Tasks tab's controllers. Registered with the shell, and built when the Complete Day tab first shows.
class TasksBinding extends Bindings {
  @override
  void dependencies() {
    final api = Get.find<ApiService>();
    Get.lazyPut<CompleteDayController>(
      () => CompleteDayController(VisitService(api), PlanService(api)),
    );
    Get.lazyPut<PlanDayController>(
      () => PlanDayController(PlanService(api), ContactService(api)),
    );
  }
}

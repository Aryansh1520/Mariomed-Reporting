import 'package:get/get.dart';

import '../../controllers/categories_controller.dart';
import '../../services/api_service.dart';
import '../../services/contact_service.dart';
import '../../services/team_dashboard_service.dart';

class CategoriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CategoriesController>(
      () => CategoriesController(
        Get.find<ContactService>(),
        TeamDashboardService(Get.find<ApiService>()),
      ),
    );
  }
}

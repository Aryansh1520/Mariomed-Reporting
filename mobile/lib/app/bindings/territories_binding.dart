import 'package:get/get.dart';

import '../../controllers/territories_controller.dart';
import '../../services/api_service.dart';
import '../../services/territory_service.dart';

class TerritoriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TerritoriesController>(
      () => TerritoriesController(TerritoryService(Get.find<ApiService>())),
    );
  }
}

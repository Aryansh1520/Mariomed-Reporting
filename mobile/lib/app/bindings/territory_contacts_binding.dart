import 'package:get/get.dart';

import '../../controllers/territory_contacts_controller.dart';
import '../../models/territory.dart';
import '../../services/api_service.dart';
import '../../services/contact_service.dart';

class TerritoryContactsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TerritoryContactsController>(
      () => TerritoryContactsController(
        ContactService(Get.find<ApiService>()),
        Get.arguments as Territory,
      ),
    );
  }
}

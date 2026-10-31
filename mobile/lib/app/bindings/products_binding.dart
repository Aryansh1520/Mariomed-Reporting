import 'package:get/get.dart';

import '../../controllers/product_form_controller.dart';
import '../../controllers/products_controller.dart';
import '../../services/api_service.dart';
import '../../services/product_service.dart';
import '../../services/team_dashboard_service.dart';

class ProductsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductsController>(
      () => ProductsController(
        Get.find<ProductService>(),
        TeamDashboardService(Get.find<ApiService>()),
      ),
    );
  }
}

class ProductFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductFormController>(
      () => ProductFormController(Get.find<ProductService>()),
    );
  }
}

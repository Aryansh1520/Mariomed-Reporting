import 'package:get/get.dart';

import '../../controllers/visit_record_controller.dart';
import '../../services/api_service.dart';
import '../../services/product_service.dart';
import '../../services/visit_service.dart';

class VisitRecordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VisitRecordController>(
      () => VisitRecordController(
        VisitService(Get.find<ApiService>()),
        Get.find<ProductService>(),
        Get.arguments as VisitRecordArgs,
      ),
    );
  }
}

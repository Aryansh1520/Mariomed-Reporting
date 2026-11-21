import 'package:get/get.dart';

import '../../controllers/unlisted_patch_controller.dart';
import '../../controllers/unlisted_patches_controller.dart';
import '../../services/api_service.dart';
import '../../services/unlisted_service.dart';

class UnlistedPatchesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UnlistedPatchesController>(
      () => UnlistedPatchesController(UnlistedService(Get.find<ApiService>())),
    );
  }
}

class UnlistedPatchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UnlistedPatchController>(
      () => UnlistedPatchController(
        UnlistedService(Get.find<ApiService>()),
        Get.arguments as UnlistedPatchArgs,
      ),
    );
  }
}

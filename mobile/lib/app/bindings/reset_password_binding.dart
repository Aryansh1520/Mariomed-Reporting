import 'package:get/get.dart';

import '../../controllers/reset_password_controller.dart';
import '../../services/auth_service.dart';

class ResetPasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ResetPasswordController>(
      () => ResetPasswordController(Get.find<AuthService>()),
    );
  }
}

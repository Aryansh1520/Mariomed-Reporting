import 'package:get/get.dart';

import '../../controllers/login_controller.dart';
import '../../services/auth_service.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginController>(
      () => LoginController(Get.find<AuthService>()),
    );
  }
}

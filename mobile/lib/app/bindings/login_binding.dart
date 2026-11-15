import 'package:get/get.dart';

import '../../controllers/login_controller.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/login_memory.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginController>(
      () => LoginController(
        Get.find<AuthService>(),
        Get.find<LoginMemory>(),
        Get.find<BiometricService>(),
      ),
    );
  }
}

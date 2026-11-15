import 'package:get/get.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/login_memory.dart';
import '../../services/product_service.dart';
import '../../services/token_store.dart';

/// Registered once at app start. App-wide services live here.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ApiService>(ApiService(), permanent: true);
    Get.put<TokenStore>(TokenStore(), permanent: true);
    Get.put<LoginMemory>(LoginMemory(), permanent: true);
    Get.put<BiometricService>(BiometricService(), permanent: true);
    Get.put<AuthService>(
      AuthService(Get.find<ApiService>(), Get.find<TokenStore>()),
      permanent: true,
    );
    Get.put<ProductService>(
      ProductService(Get.find<ApiService>()),
      permanent: true,
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../services/app_exception.dart';
import '../services/auth_service.dart';

class LoginController extends GetxController {
  LoginController(this._authService);

  final AuthService _authService;
  final identifier = TextEditingController();
  final password = TextEditingController();
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final isPasswordHidden = true.obs;

  void togglePasswordVisibility() => isPasswordHidden.toggle();

  Future<void> signIn() async {
    if (identifier.text.trim().isEmpty || password.text.isEmpty) {
      errorMessage.value = 'Enter your mobile or email and password.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _authService.signIn(
        identifier: identifier.text,
        password: password.text,
      );
      Get.offAllNamed(AppRoutes.home);
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> forgotPassword() async {
    final id = identifier.text.trim();
    if (id.isEmpty) {
      errorMessage.value = 'Enter your mobile or email first.';
      return;
    }
    try {
      await _authService.sendPasswordReset(id);
      Get.toNamed(AppRoutes.passwordReset, arguments: id);
    } on AppException catch (e) {
      errorMessage.value = e.message;
    }
  }

  @override
  void onClose() {
    identifier.dispose();
    password.dispose();
    super.onClose();
  }
}

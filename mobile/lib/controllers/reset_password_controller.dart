import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../core/widgets/app_dialogs.dart';
import '../services/app_exception.dart';
import '../services/auth_service.dart';

class ResetPasswordController extends GetxController {
  ResetPasswordController(this._authService);

  final AuthService _authService;
  final identifier = TextEditingController(text: Get.arguments as String?);
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  Future<void> submit() async {
    final problem = _problem();
    if (problem != null) {
      errorMessage.value = problem;
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _authService.confirmPasswordReset(
        identifier: identifier.text,
        code: code.text,
        newPassword: password.text,
      );
      await AppDialogs.success(
        'Password changed',
        'Sign in with your new password.',
      );
      Get.offAllNamed(AppRoutes.login);
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  String? _problem() {
    if (identifier.text.trim().isEmpty) return 'Enter your mobile or email.';
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      return 'Enter the six-digit code from your email.';
    }
    if (password.text.length < 8) {
      return 'Use at least 8 characters for the new password.';
    }
    if (password.text != confirmPassword.text) {
      return 'The two passwords do not match.';
    }
    return null;
  }

  @override
  void onClose() {
    identifier.dispose();
    code.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.onClose();
  }
}

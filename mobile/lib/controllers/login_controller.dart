import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../core/widgets/app_dialogs.dart';
import '../services/app_exception.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/login_memory.dart';

class LoginController extends GetxController {
  LoginController(this._authService, this._memory, this._biometrics);

  final AuthService _authService;
  final LoginMemory _memory;
  final BiometricService _biometrics;
  final identifier = TextEditingController();
  final password = TextEditingController();
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final isPasswordHidden = true.obs;
  final rememberMe = true.obs;

  /// True when fingerprint or face sign-in is on, the device supports it, and a saved session exists.
  final biometricReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreChoices();
  }

  void togglePasswordVisibility() => isPasswordHidden.toggle();

  Future<void> _restoreChoices() async {
    final saved = await _memory.read();
    rememberMe.value = saved.rememberMe;
    if (saved.identifier != null && identifier.text.isEmpty) {
      identifier.text = saved.identifier!;
    }
    biometricReady.value =
        await _memory.readBiometricSignIn() &&
        await _biometrics.isAvailable() &&
        await _authService.hasStoredSession();
    if (biometricReady.value) await signInWithBiometrics();
  }

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
        rememberMe: rememberMe.value,
      );
      await _memory.save(
        rememberMe: rememberMe.value,
        identifier: identifier.text.trim(),
      );
      await _offerBiometricSignIn();
      Get.offAllNamed(AppRoutes.home);
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithBiometrics() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final confirmed = await _biometrics.confirmIdentity(
        'Sign in to My Mariomed',
      );
      if (!confirmed) return;
      final restored = await _authService.signInWithStoredSession();
      if (restored) {
        Get.offAllNamed(AppRoutes.home);
        return;
      }
      biometricReady.value = false;
      errorMessage.value = 'Your saved sign-in has ended. Enter your password.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Turns fingerprint or face sign-in off on this device. The next password sign-in offers it again.
  Future<void> turnOffBiometricSignIn() async {
    await _memory.saveBiometricSignIn(false);
    biometricReady.value = false;
  }

  /// Offered once, after a sign-in that keeps the session. Declining is not remembered, so it is offered again.
  Future<void> _offerBiometricSignIn() async {
    if (!rememberMe.value || await _memory.readBiometricSignIn()) return;
    if (!await _biometrics.isAvailable()) return;
    final turnOn = await AppDialogs.confirm(
      title: 'Sign in with biometrics?',
      message: 'Next time, unlock with your fingerprint or face instead of typing your password.',
      confirmLabel: 'Turn on',
      cancelLabel: 'Not now',
    );
    if (turnOn) await _memory.saveBiometricSignIn(true);
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

import 'package:shared_preferences/shared_preferences.dart';

/// The sign-in choices kept on this device: the Remember me tick, the mobile or email last used,
/// and whether fingerprint or face sign-in is on. The password is never stored.
class LoginMemory {
  static const _rememberKey = 'remember_me';
  static const _identifierKey = 'remembered_identifier';
  static const _biometricKey = 'biometric_sign_in';

  /// Ticked by default, so a first sign-in keeps the user signed in across restarts.
  Future<({bool rememberMe, String? identifier})> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        rememberMe: prefs.getBool(_rememberKey) ?? true,
        identifier: prefs.getString(_identifierKey),
      );
    } on Exception {
      return (rememberMe: true, identifier: null);
    }
  }

  Future<void> save({
    required bool rememberMe,
    required String identifier,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberKey, rememberMe);
      if (rememberMe) {
        await prefs.setString(_identifierKey, identifier);
      } else {
        await prefs.remove(_identifierKey);
      }
    } on Exception {
      // The sign-in still works; the choices are only lost on the next launch.
    }
  }

  Future<bool> readBiometricSignIn() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_biometricKey) ??
          false;
    } on Exception {
      return false;
    }
  }

  Future<void> saveBiometricSignIn(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(
        _biometricKey,
        value,
      );
    } on Exception {
      // The choice applies to the next sign-in attempt only; the default is off.
    }
  }
}

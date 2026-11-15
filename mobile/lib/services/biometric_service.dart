import 'package:local_auth/local_auth.dart';

/// Fingerprint or face unlock. Reports false, rather than throwing, where the device or platform has no biometrics.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  /// Biometrics only, with no device PIN fallback: a PIN would let anyone holding an unlocked phone sign in.
  Future<bool> confirmIdentity(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Exception {
      return false;
    }
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the session token so a restart does not sign the user out.
/// Secure storage is used first. Where the platform has no secure storage (Linux without a keyring service),
/// the token is kept in shared preferences instead, which is not encrypted.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'access_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      final token = await _storage.read(key: _key);
      if (token != null) return token;
    } on Exception {
      // Secure storage that cannot be read falls through to the preferences copy.
    }
    return _readFallback();
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
      return;
    } on Exception {
      // No secure storage on this platform: keep the token where the next launch can find it.
    }
    await _writeFallback(token);
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Nothing more to do here; the fallback copy is removed below.
    }
    await _deleteFallback();
  }

  Future<String?> _readFallback() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } on Exception {
      return null;
    }
  }

  Future<void> _writeFallback(String token) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, token);
    } on Exception {
      // The session still works in memory; it is only lost on the next restart.
    }
  }

  Future<void> _deleteFallback() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } on Exception {
      // Nothing to remove if the preferences cannot be opened.
    }
  }
}

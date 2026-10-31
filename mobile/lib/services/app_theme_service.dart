import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The theme the user picked. Light until the user chooses otherwise, and the choice is kept across restarts.
class AppThemeService {
  static const _storageKey = 'theme_mode';

  final _mode = ThemeMode.light.obs;

  ThemeMode get mode => _mode.value;

  Rx<ThemeMode> get observedMode => _mode;

  /// Reads the saved choice before the first frame. A missing or unreadable value keeps light.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      _mode.value = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.light,
      );
    } on Exception {
      // Storage that cannot be opened keeps the default theme for this run.
    }
  }

  Future<void> setMode(ThemeMode value) async {
    _mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, value.name);
    } on Exception {
      // The choice still applies for this run; it is only lost on the next restart.
    }
  }
}

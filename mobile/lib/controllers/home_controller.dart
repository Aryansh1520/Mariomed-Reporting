import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../models/current_user.dart';
import '../models/dashboard.dart';
import '../services/app_exception.dart';
import '../services/app_theme_service.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';

/// Home and the profile tab. Home shows the dashboard the server built for the caller's permissions.
class HomeController extends GetxController {
  HomeController(this._authService, this._themeService, this._dashboardService);

  final AuthService _authService;
  final AppThemeService _themeService;
  final DashboardService _dashboardService;
  final _dashboard = Rxn<Dashboard>();

  CurrentUser? get user => _authService.currentUser;

  ThemeMode get themeMode => _themeService.mode;

  /// The sections the caller may see. Null until the first load succeeds.
  Dashboard? get dashboard => _dashboard.value;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  /// A failure leaves the dashboard empty rather than blocking Home.
  Future<void> loadDashboard() async {
    try {
      _dashboard.value = await _dashboardService.fetchDashboard();
    } on AppException {
      _dashboard.value = null;
    }
  }

  Future<void> setThemeMode(ThemeMode value) => _themeService.setMode(value);

  Future<void> signOut() async {
    await _authService.signOut();
    Get.offAllNamed(AppRoutes.login);
  }
}

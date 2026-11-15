import 'package:get/get.dart';

import '../controllers/admin_controller.dart';
import '../controllers/categories_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/performance_controller.dart';
import '../controllers/products_controller.dart';
import '../controllers/team_dashboard_controller.dart';
import '../controllers/territories_controller.dart';
import '../controllers/territory_contacts_controller.dart';

/// Reloads the read-only screens that are still alive, so nothing shows figures from before the app was backgrounded.
/// Screens that are not open load their data the first time they are shown. Forms are left out, since a reload
/// would throw away what the user is typing.
abstract class AppRefresh {
  static Future<void> run() => Future.wait([
    _reload<HomeController>((c) => c.loadDashboard()),
    _reload<TerritoriesController>((c) => c.refreshMap()),
    _reload<TerritoryContactsController>((c) => c.load()),
    _reload<ProductsController>((c) => c.loadProducts()),
    _reload<CategoriesController>((c) => c.load()),
    _reload<AdminController>((c) => c.load()),
    _reload<TeamDashboardController>((c) => c.load()),
    _reload<PerformanceController>((c) => c.load()),
  ]);

  /// A failed reload keeps what is already on screen.
  static Future<void> _reload<T>(
    Future<void> Function(T controller) load,
  ) async {
    if (!Get.isRegistered<T>()) return;
    try {
      await load(Get.find<T>());
    } on Exception {
      // The screen keeps its current data until the next refresh.
    }
  }
}

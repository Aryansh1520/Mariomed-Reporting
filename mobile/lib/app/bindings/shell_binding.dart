import 'package:get/get.dart';

import '../../controllers/home_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../services/app_theme_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/performance_controller.dart';
import '../../controllers/team_dashboard_controller.dart';
import '../../services/member_report_service.dart';
import '../../services/admin_service.dart';
import '../../services/team_dashboard_service.dart';
import 'tasks_binding.dart';
import 'territories_binding.dart';

/// The signed-in area: the bottom tabs and the screens behind them.
class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShellController>(() => ShellController());
    TerritoriesBinding().dependencies();
    TasksBinding().dependencies();
    Get.lazyPut<AdminController>(
      () => AdminController(AdminService(Get.find<ApiService>())),
    );
    Get.lazyPut<PerformanceController>(
      () => PerformanceController(MemberReportService(Get.find<ApiService>())),
    );
    Get.lazyPut<TeamDashboardController>(
      () =>
          TeamDashboardController(TeamDashboardService(Get.find<ApiService>())),
    );
    Get.lazyPut<HomeController>(
      () => HomeController(
        Get.find<AuthService>(),
        Get.find<AppThemeService>(),
        DashboardService(Get.find<ApiService>()),
      ),
    );
  }
}

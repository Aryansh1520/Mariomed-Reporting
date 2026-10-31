import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../services/auth_service.dart';
import 'app_routes.dart';

/// Pages need a session. Browsers open any URL directly, so the check lives on the route,
/// not only on the buttons that lead to it.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Get.find<AuthService>().isSignedIn) return null;
    return const RouteSettings(name: AppRoutes.login);
  }
}

/// The login page is for visitors without a session. A signed-in visitor goes straight in.
class GuestGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.find<AuthService>().isSignedIn) return null;
    return const RouteSettings(name: AppRoutes.home);
  }
}

/// Lets a page through only when the signed-in role grants [permission].
class PermissionGuard extends GetMiddleware {
  PermissionGuard(this.permission);

  final String permission;

  @override
  RouteSettings? redirect(String? route) {
    if (Get.find<AuthService>().can(permission)) return null;
    return const RouteSettings(name: AppRoutes.home);
  }
}

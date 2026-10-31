import 'package:get/get.dart';

import '../models/role.dart';
import '../models/team_user.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/app_exception.dart';

/// The team and the roles. Each list loads only when the caller may see it: a list the server refuses stays empty.
class AdminController extends GetxController {
  AdminController(this._service);

  final AdminService _service;

  final users = <TeamUser>[].obs;
  final roles = <Role>[].obs;
  final permissions = <PermissionDef>[].obs;
  final isLoading = true.obs;
  final isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    users.assignAll(await _attempt(_service.listUsers, const []));
    roles.assignAll(await _attempt(_service.listRoles, const []));
    permissions.assignAll(await _attempt(_service.listPermissions, const []));
    isLoading.value = false;
  }

  /// Loads one list. A permission the caller lacks makes the server refuse it, which leaves the list empty.
  Future<List<T>> _attempt<T>(
    Future<List<T>> Function() fetch,
    List<T> fallback,
  ) async {
    try {
      return await fetch();
    } on AppException {
      return fallback;
    }
  }

  Future<String?> setActive(TeamUser user, {required bool isActive}) =>
      _run(() async {
        await _service.setActive(user.id, isActive: isActive);
        users.assignAll(await _service.listUsers());
      });

  Future<String?> createUser({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String roleCode,
  }) => _run(() async {
    await _service.createUser(
      fullName: fullName,
      email: email,
      mobile: mobile,
      password: password,
      roleCode: roleCode,
    );
    users.assignAll(await _service.listUsers());
  });

  Future<String?> saveRole({
    Role? role,
    required String name,
    required List<RoleGrant> grants,
  }) => _run(() async {
    if (role == null) {
      await _service.createRole(name: name, grants: grants);
    } else {
      await _service.updateRole(role.id, name: name, grants: grants);
    }
    await _reloadAfterRoleChange();
  });

  Future<String?> deleteRole(Role role) => _run(() async {
    await _service.deleteRole(role.id);
    await _reloadAfterRoleChange();
  });

  /// A role change can rename roles on the team list and change the signed-in user's own permissions.
  Future<void> _reloadAfterRoleChange() async {
    roles.assignAll(await _service.listRoles());
    users.assignAll(await _attempt(_service.listUsers, const []));
    await Get.find<AuthService>().refreshCurrentUser();
  }

  Future<String?> _run(Future<void> Function() change) async {
    isBusy.value = true;
    try {
      await change();
      return null;
    } on AppException catch (e) {
      return e.message;
    } finally {
      isBusy.value = false;
    }
  }
}

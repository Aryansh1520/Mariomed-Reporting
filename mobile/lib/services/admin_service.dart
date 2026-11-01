import '../models/role.dart';
import '../models/team_user.dart';
import '../models/territory.dart';
import 'api_service.dart';

/// Team and role endpoints. Each call needs the matching permission, and the server checks it.
class AdminService {
  AdminService(this._api);

  final ApiService _api;

  Future<List<TeamUser>> listUsers() => _api.getData<List<TeamUser>>(
    '/users?page_size=100',
    (data) {
      final items = ApiService.asJsonMap(data)['items'] as List<Object?>;
      return [
        for (final item in items) TeamUser.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  Future<void> createUser({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String roleCode,
  }) => _api.postData<void>(
    '/users',
    (_) {},
    body: {
      'full_name': fullName,
      'email': email,
      'mobile': mobile,
      'password': password,
      'role_code': roleCode,
    },
  );

  Future<void> setActive(int userId, {required bool isActive}) =>
      _api.postData<void>(
        '/users/$userId/activation',
        (_) {},
        body: {'is_active': isActive},
      );

  Future<List<Territory>> listTerritories() =>
      _api.getData<List<Territory>>('/territories/map', (data) {
        final items = ApiService.asJsonMap(data)['territories'] as List<Object?>;
        return [
          for (final item in items)
            Territory.fromJson(ApiService.asJsonMap(item)),
        ];
      });

  Future<List<int>> listUserTerritoryIds(int userId) =>
      _api.getData<List<int>>('/territories/users/$userId', (data) {
        final ids = ApiService.asJsonMap(data)['territory_ids'] as List<Object?>;
        return [for (final id in ids) id as int];
      });

  /// Replaces the whole list: the zones and subzones not sent are taken away.
  Future<void> setUserTerritoryIds(int userId, List<int> territoryIds) =>
      _api.putData<void>(
        '/territories/users/$userId',
        (_) {},
        body: {'territory_ids': territoryIds},
      );

  Future<List<Role>> listRoles() => _api.getData<List<Role>>('/roles', (data) {
    final items = data as List<Object?>;
    return [
      for (final item in items) Role.fromJson(ApiService.asJsonMap(item)),
    ];
  });

  Future<List<PermissionDef>> listPermissions() =>
      _api.getData<List<PermissionDef>>('/roles/permissions', (data) {
        final items = data as List<Object?>;
        return [
          for (final item in items)
            PermissionDef.fromJson(ApiService.asJsonMap(item)),
        ];
      });

  Future<void> createRole({
    required String name,
    required List<RoleGrant> grants,
  }) => _api.postData<void>(
    '/roles',
    (_) {},
    body: {
      'name': name,
      'grants': [for (final grant in grants) grant.toJson()],
    },
  );

  Future<void> updateRole(
    int roleId, {
    required String name,
    required List<RoleGrant> grants,
  }) => _api.patchData<void>(
    '/roles/$roleId',
    (_) {},
    body: {
      'name': name,
      'grants': [for (final grant in grants) grant.toJson()],
    },
  );

  Future<void> deleteRole(int roleId) =>
      _api.deleteData<void>('/roles/$roleId', (_) {});
}

import 'permission_grant.dart';

/// The signed-in user from /auth/me. The permission list drives what the app shows.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.roleCode,
    required this.roleName,
    required this.permissions,
  });

  factory CurrentUser.fromJson(Map<String, Object?> json) => CurrentUser(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    mobile: json['mobile'] as String,
    roleCode: json['role_code'] as String,
    roleName: json['role_name'] as String,
    permissions: [
      for (final grant in json['permissions'] as List<Object?>)
        PermissionGrant.fromJson(grant as Map<String, Object?>),
    ],
  );

  final int id;
  final String fullName;
  final String email;
  final String mobile;
  final String roleCode;
  final String roleName;
  final List<PermissionGrant> permissions;

  bool can(String code) => permissions.any((grant) => grant.code == code);

  /// The scope the caller holds for a permission, or null when they do not hold it.
  String? scopeOf(String code) {
    for (final grant in permissions) {
      if (grant.code == code) return grant.scope;
    }
    return null;
  }

  /// Whether the caller works in the field and reports their own calls. A grant of `all` is oversight, not reporting.
  bool get reportsPersonally {
    final scope = scopeOf('visits.manage');
    return scope != null && scope != 'all';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'mobile': mobile,
    'role_code': roleCode,
    'role_name': roleName,
    'permissions': [for (final grant in permissions) grant.toJson()],
  };
}

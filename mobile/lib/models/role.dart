/// One permission a role holds. Scope is null for permissions that are not scoped, such as create.
class RoleGrant {
  const RoleGrant({required this.code, this.scope});

  factory RoleGrant.fromJson(Map<String, Object?> json) =>
      RoleGrant(code: json['code'] as String, scope: json['scope'] as String?);

  final String code;
  final String? scope;

  Map<String, Object?> toJson() => {'code': code, 'scope': scope};
}

/// A role: a name and the permissions it holds. The admin role is locked and cannot be edited.
class Role {
  const Role({
    required this.id,
    required this.code,
    required this.name,
    required this.isLocked,
    required this.grants,
  });

  factory Role.fromJson(Map<String, Object?> json) => Role(
    id: json['id'] as int,
    code: json['code'] as String,
    name: json['name'] as String,
    isLocked: json['is_locked'] as bool,
    grants: [
      for (final grant in json['grants'] as List<Object?>)
        RoleGrant.fromJson((grant as Map).cast()),
    ],
  );

  final int id;
  final String code;
  final String name;
  final bool isLocked;
  final List<RoleGrant> grants;
}

/// A permission in the catalogue. Roles pick from these; new features add entries on the server.
class PermissionDef {
  const PermissionDef({
    required this.code,
    required this.description,
    required this.module,
    required this.scoped,
    required this.requires,
  });

  factory PermissionDef.fromJson(Map<String, Object?> json) => PermissionDef(
    code: json['code'] as String,
    description: json['description'] as String,
    module: json['module'] as String,
    scoped: json['scoped'] as bool,
    requires: json['requires'] as String?,
  );

  final String code;
  final String description;
  final String module;
  final bool scoped;

  /// The permission this one needs in order to mean anything. Switching it off switches this one off too.
  final String? requires;
}

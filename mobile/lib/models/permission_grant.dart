/// One permission the signed-in role holds, and the scope it reaches.
class PermissionGrant {
  const PermissionGrant({required this.code, required this.scope});

  factory PermissionGrant.fromJson(Map<String, Object?> json) =>
      PermissionGrant(
        code: json['code'] as String,
        scope: json['scope'] as String,
      );

  final String code;
  final String scope;

  Map<String, Object?> toJson() => {'code': code, 'scope': scope};
}

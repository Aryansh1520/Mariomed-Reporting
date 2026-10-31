/// A person in the team, as the admin sees them.
class TeamUser {
  const TeamUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.roleCode,
    required this.roleName,
    required this.isActive,
  });

  factory TeamUser.fromJson(Map<String, Object?> json) => TeamUser(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    mobile: json['mobile'] as String,
    roleCode: json['role_code'] as String,
    roleName: json['role_name'] as String,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String fullName;
  final String email;
  final String mobile;
  final String roleCode;
  final String roleName;
  final bool isActive;
}

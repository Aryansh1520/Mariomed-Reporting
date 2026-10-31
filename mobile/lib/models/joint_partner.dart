/// Another rep who can join a call on a contact: assigned to the same zone or subzone.
class JointPartner {
  const JointPartner({required this.userId, required this.fullName});

  factory JointPartner.fromJson(Map<String, Object?> json) => JointPartner(
    userId: json['user_id'] as int,
    fullName: json['full_name'] as String,
  );

  final int userId;
  final String fullName;
}

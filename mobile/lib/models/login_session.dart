import 'current_user.dart';

class LoginSession {
  const LoginSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  factory LoginSession.fromJson(Map<String, Object?> json) => LoginSession(
    accessToken: json['access_token'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    user: CurrentUser.fromJson(json['user'] as Map<String, Object?>),
  );

  final String accessToken;
  final DateTime expiresAt;
  final CurrentUser user;
}

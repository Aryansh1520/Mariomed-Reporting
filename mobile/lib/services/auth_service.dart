import 'package:get/get.dart';

import '../models/current_user.dart';
import '../models/login_session.dart';
import 'api_service.dart';
import 'app_exception.dart';
import 'token_store.dart';

/// Sign-in, sign-out and the current user, backed by the API. The token is kept in secure storage.
class AuthService {
  AuthService(this._api, this._tokenStore) {
    _api.onPermissionRefused = () => refreshCurrentUser().catchError((_) {});
  }

  final ApiService _api;
  final TokenStore _tokenStore;

  CurrentUser? _currentUser;

  /// Bumps each time the signed-in user's permissions are loaded, so screens that depend on them rebuild.
  final permissionsRevision = 0.obs;

  bool get isSignedIn => _api.hasAccessToken;

  CurrentUser? get currentUser => _currentUser;

  /// True when the signed-in user's role grants [permission].
  bool can(String permission) => _currentUser?.can(permission) ?? false;

  bool get reportsPersonally => _currentUser?.reportsPersonally ?? false;

  /// Runs once at startup. A stored token that the server no longer accepts is dropped.
  Future<void> restoreSession() async {
    final token = await _tokenStore.read();
    if (token == null) return;
    _api.setAccessToken(token);
    try {
      await _fetchCurrentUser();
    } on AppException {
      _api.setAccessToken(null);
      await _tokenStore.delete();
    }
  }

  Future<CurrentUser> signIn({
    required String identifier,
    required String password,
  }) async {
    final session = await _api.postData<LoginSession>(
      '/auth/login',
      (data) => LoginSession.fromJson(ApiService.asJsonMap(data)),
      body: {'identifier': identifier.trim(), 'password': password},
      authenticated: false,
    );
    _api.setAccessToken(session.accessToken);
    _currentUser = session.user;
    await _tokenStore.write(session.accessToken);
    return session.user;
  }

  /// Local sign-out always succeeds, even when the server cannot be reached.
  Future<void> signOut() async {
    try {
      await _api.postData<void>('/auth/logout', (_) {});
    } on AppException {
      // The token is dropped below either way, and it expires on the server.
    }
    _api.setAccessToken(null);
    _currentUser = null;
    await _tokenStore.delete();
  }

  /// The backend answers the same way whether or not the account exists.
  Future<void> sendPasswordReset(String identifier) => _api.postData<void>(
    '/auth/password-reset/request',
    (_) {},
    body: {'identifier': identifier.trim()},
    authenticated: false,
  );

  /// Sets a new password with the code from the reset email. The server ends every open session for the account.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) => _api.postData<void>(
    '/auth/password-reset/confirm',
    (_) {},
    body: {'token': code.trim(), 'new_password': newPassword},
    authenticated: false,
  );

  /// Reloads the signed-in user's permissions, so a role change made elsewhere takes effect without signing in again.
  Future<void> refreshCurrentUser() async {
    await _fetchCurrentUser();
  }

  Future<CurrentUser> _fetchCurrentUser() async {
    final user = await _api.getData<CurrentUser>(
      '/auth/me',
      (data) => CurrentUser.fromJson(ApiService.asJsonMap(data)),
    );
    _currentUser = user;
    permissionsRevision.value++;
    return user;
  }
}

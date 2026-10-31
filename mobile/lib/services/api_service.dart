import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import 'app_exception.dart';

/// Single HTTP entry point for the backend. Unwraps the API envelope {success, message, data}
/// so callers only ever see the data or an AppException.
class ApiService extends GetConnect {
  String? _accessToken;

  /// Called when the server refuses a request for lack of permission, so the caller can reload what they may do.
  void Function()? onPermissionRefused;

  @override
  void onInit() {
    httpClient.baseUrl = AppConstants.apiBaseUrl;
    httpClient.timeout = const Duration(seconds: 15);
    super.onInit();
  }

  /// Held in memory only. The token is also written to secure storage by the auth service.
  void setAccessToken(String? token) => _accessToken = token;

  bool get hasAccessToken => _accessToken != null;

  Future<T> getData<T>(String path, T Function(Object? data) decode) async {
    final response = await get<Object?>(path, headers: _headers());
    return _unwrap(response, decode);
  }

  Future<T> putData<T>(
    String path,
    T Function(Object? data) decode, {
    Map<String, Object?> body = const {},
  }) async {
    final response = await put<Object?>(path, body, headers: _headers());
    return _unwrap(response, decode);
  }

  Future<T> patchData<T>(
    String path,
    T Function(Object? data) decode, {
    Map<String, Object?> body = const {},
  }) async {
    final response = await patch<Object?>(path, body, headers: _headers());
    return _unwrap(response, decode);
  }

  Future<T> deleteData<T>(String path, T Function(Object? data) decode) async {
    final response = await delete<Object?>(path, headers: _headers());
    return _unwrap(response, decode);
  }

  Future<T> postData<T>(
    String path,
    T Function(Object? data) decode, {
    Map<String, Object?> body = const {},
    bool authenticated = true,
  }) async {
    final response = await post<Object?>(
      path,
      body,
      headers: _headers(authenticated: authenticated),
    );
    return _unwrap(response, decode);
  }

  /// Use inside a decode function to read a JSON object from the envelope's data.
  static Map<String, Object?> asJsonMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw const AppException('The server sent an unexpected response.');
  }

  Map<String, String> _headers({bool authenticated = true}) {
    final token = _accessToken;
    if (!authenticated || token == null) return const {};
    return {'authorization': 'Bearer $token'};
  }

  T _unwrap<T>(Response<Object?> response, T Function(Object? data) decode) {
    if (response.statusCode == 403) onPermissionRefused?.call();
    final body = response.body;
    if (body is! Map) {
      throw const AppException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    final envelope = body.cast<String, Object?>();
    if (envelope['success'] != true) {
      throw AppException(
        envelope['message'] as String? ?? 'Something went wrong. Try again.',
      );
    }
    return decode(envelope['data']);
  }
}

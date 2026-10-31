/// A failure the user can read. Services throw it; controllers turn it into screen state.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

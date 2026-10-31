abstract class AppConstants {
  static const appName = 'My Mariomed';

  /// How many days back a visit may still be recorded. Mirrors the server's reporting_grace_days.
  static const visitGraceDays = 4;

  /// How far back the Complete Day calendar shows days. Older days are read-only history.
  static const historyDays = 365;

  /// How many days ahead a rep may plan or mark leave. Mirrors the server's plan horizon.
  static const planHorizonDays = 31;

  /// Override per build with: flutter run --dart-define=API_BASE_URL=http://...
  /// 10.0.2.2 is the host machine as seen from the Android emulator.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8200/api/v1',
  );
}

/// App-wide config. Dili ibutang ang DB secrets dinhi - JWT token lang.
class AppConfig {
  /// Override at build/run time:
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration pollInterval = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 15);
}

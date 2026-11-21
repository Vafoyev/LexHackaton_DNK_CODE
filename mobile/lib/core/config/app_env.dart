import 'package:flutter/foundation.dart';

class AppEnv {
  const AppEnv._();

  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  /// Resolves API base URL dynamically depending on the execution target:
  /// - Explicit override via `--dart-define=API_BASE_URL=...`
  /// - Android emulator defaults to `http://10.0.2.2:8080`
  /// - iOS Simulator / macOS / Web / Desktop defaults to `http://localhost:8080`
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static String get apiV1BaseUrl => '$apiBaseUrl/api/v1';

  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: true,
  );

  static const String appVersion = '3.2.0';
}

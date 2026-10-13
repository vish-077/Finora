import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { development, staging, production }

class AppConfig {
  AppConfig._();

  /// Safe accessor — returns null when dotenv hasn't been loaded
  /// (e.g. in unit tests) instead of throwing NotInitializedError.
  static String? _raw(String key) =>
      dotenv.isInitialized ? dotenv.env[key] : null;

  static AppEnvironment get environment {
    final env = _raw('APP_ENV') ?? 'development';
    return switch (env) {
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => AppEnvironment.development,
    };
  }

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isProduction => environment == AppEnvironment.production;

  static String get appName => _raw('APP_NAME') ?? 'FINORA';
  static String get appVersion => _raw('APP_VERSION') ?? '1.0.0';


  static String get geminiApiBaseUrl =>
      _raw('GEMINI_API_BASE_URL') ??
      'https://generativelanguage.googleapis.com/v1beta';

  static int get pinMaxAttempts =>
      int.tryParse(_raw('PIN_MAX_ATTEMPTS') ?? '5') ?? 5;

  static int get pinLockoutMinutes =>
      int.tryParse(_raw('PIN_LOCKOUT_MINUTES') ?? '30') ?? 30;

  static int get autoLockMinutes =>
      int.tryParse(_raw('AUTO_LOCK_MINUTES') ?? '5') ?? 5;

  static bool get enableTalkerOverlay =>
      (_raw('ENABLE_TALKER_OVERLAY') ?? 'false').toLowerCase() == 'true';

  static bool get featureAiBox =>
      (_raw('FEATURE_AI_BOX') ?? 'true').toLowerCase() == 'true';

  static bool get featureReceiptScanner =>
      (_raw('FEATURE_RECEIPT_SCANNER') ?? 'true').toLowerCase() == 'true';

  static bool get featureGoals =>
      (_raw('FEATURE_GOALS') ?? 'true').toLowerCase() == 'true';

  /// First retry delay for a failed sync push; doubles per attempt.
  static int get syncRetryBaseSeconds =>
      int.tryParse(_raw('SYNC_RETRY_BASE_SECONDS') ?? '5') ?? 5;

  /// How long a queued change keeps retrying before it is dropped.
  static int get syncMaxRetryHours =>
      int.tryParse(_raw('SYNC_MAX_RETRY_HOURS') ?? '24') ?? 24;
}
